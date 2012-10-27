# -*- coding: utf-8 -*-

# t.string   "provider"
# t.string   "uid"
# t.string   "name"
# t.string   "email"
# t.datetime "created_at",                   :null => false
# t.datetime "updated_at",                   :null => false
# t.string   "profile_image_filenameimage",  :default => ""
# t.boolean  "available",  :default => true
# t.string   "password_digest"
# t.string   "uuid"

class User < ActiveRecord::Base
  # Association
  has_many :posts
  has_many :comments
  has_many :stocks

  has_many :project_members
  has_many :projects, through: :project_members

  # Attributes
  has_secure_password
  attr_accessor :profile_image
  attr_accessible :uuid, :name, :email, :provider, :uid, :password, :password_confirmation, :password_digest, :profile_image_filename, :profile_image

  # Validation
  validate :thirdparty_oauth_valid?
  validates :name, presence: { mesage: 'は、必須です' }, uniqueness: { case_sensitive: false, message: 'は、既に登録されています' }
  validates :email, presence: { mesage: 'は、必須です' }, uniqueness: { case_sensitive: false, message: 'は、既に登録されています' }

  # Scope
  scope :name_is, lambda { |name| where(["lower(name) = ?", name.downcase]) }
  scope :thirdparty_auth_data_is, lambda { |auth| where(provider: auth[:provider], uid: auth[:uid]) }
  before_save :set_uuid, :set_image

  def set_uuid
    begin
      self.uuid = generate_uuid
    rescue => e
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  def set_image
    begin
      save_profile_image!
    rescue => e
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  # Custom Setter
  def uuid=(value)
    write_attribute(:uuid, value) if uuid.nil?
    raise UITalk::EmptyUUID, "uuid `uuid` is empty" if uuid.to_s == ""
    raise UITalk::NotUniqueUUID, "uuid `uuid` is already exists" if User.where(uuid: uuid).count > 0
  end

  # Custom Setter/Getter
  def generate_uuid
    OpenSSL::Digest::SHA1.hexdigest(UUIDTools::UUID.timestamp_create).downcase
  end

  module ProfileImageMethods
    module Config
      def profile_image_dir
        raise UITalk::Error, "uuid is blank" if uuid.to_s == ""

        dir = "public/uploaded/#{self.class.to_s.underscore}/#{uuid}"
        dir_expanded_path = Pathname.new File.expand_path(dir)

        FileUtils.mkdir_p(dir_expanded_path) unless File.exists?(dir_expanded_path)
        dir
      end
    end
    include Config

    module Uploader
      def save_profile_image!
        filename_without_ext = generate_uuid
        if profile_image
          self.profile_image_filename = "#{filename_without_ext}.#{profile_image_ext}"
          save_profile_image
        else
          self.profile_image_filename = "#{filename_without_ext}.#{default_profile_image_ext}"
          save_default_profile_image
        end
      end

      def save_profile_image
        File.open(profile_image_path, 'wb') { |f| f.write(profile_image.read) }
      end

      def save_default_profile_image
        File.open(profile_image_path, 'wb') { |f|
          File.open(profile_default_image_path, 'r') { |f_for_read|
            f.write(f_for_read.read)
          }
        }
      end
    end
    include Uploader

    module Ext
      def profile_image_ext
        return default_profile_image_ext unless [ 'image/png', 'image/jpg', 'image/jpeg', 'image/gif' ].include?(profile_image.content_type)
        profile_image.content_type.gsub(/^image\//, "")
      end

      def default_profile_image_ext
        profile_default_image_path.extname
      end
    end
    include Ext

    module Path
      def profile_image_path
        Rails.root.join(profile_image_dir).join(profile_image_filename)
      end

      def profile_default_image_path
        Rails.root.join("public/defaults/user.png")
      end
    end
    include Path

    module Url
      def profile_image_url
        # if configured upload_server, set it for host
        host = begin
          UITalk::Application.config.upload_server
        rescue
          ""
        end

        "#{host}/#{profile_image_dir.gsub(/public\//, '')}/#{profile_image_filename}"
      end
    end
    include Url
  end

  include ProfileImageMethods

  def to_param
    name
  end

  def provider_list
    [ 'twitter' ]
  end

  class << self
    # Public: Optimize 3'd party OAuth data that returned by omniauth for User model.
    #
    # auth - A Hash with the 3'rd party OAuth data that returned by omniauth.
    #        :provider  - A String identifying 3'rd party OAuth provider.
    #        :uid  - A String identifying 3'rd party OAuth uid.
    #
    # Examples
    #
    #   optimize_data_from_omniauth_for_fields({
    #     provider: "facebook",
    #     uid: "1111",
    #     info: {
    #       name: "toqoz",
    #       email: "toqoz403@gmail.com"
    #     }
    #   })
    #   # => { provider: "facebook", uid: "1111", name: "toqoz", email: "toqoz403@gmail.com" }
    #
    # Returns a Hash of optimized for User model.
    def optimize_data_from_omniauth_for_fields(auth)
      user = {}
      user[:provider] = auth[:provider]
      user[:uid] = auth[:uid]
      if auth[:info]
        user[:name] = auth[:info][:name] || ""
        user[:email] = auth[:info][:email] || ""
      end
      user
    end
  end

  private

  def include_by_provider_list?
    provider_list().include? provider
  end

  def thirdparty_oauth_valid?
    provider_is_empty = (provider.nil? || provider.length <= 0)
    uid_is_empty = (uid.nil? || uid.length <= 0)

    unless provider_is_empty
      errors.add(:provider, 'providerが不正') if !include_by_provider_list?
      if uid_is_empty
        errors.add(:uid, 'uidが空です')
      else
        errors.add(:uid, 'このuidは既に使われています') if User.where(uid: uid).count > 0
      end
    end
    unless uid_is_empty
      errors.add(:provider, 'providerが空です') if provider_is_empty
    end
  end
end
