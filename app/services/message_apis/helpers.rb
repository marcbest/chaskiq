module MessageApis
  module Helpers
    extend ActiveSupport::Concern

    def keygen
      ("a".."z").to_a.sample(8).join
    end

    def text_block(text)
      lines = text.split("\n").delete_if(&:empty?)
      {
        blocks: lines.map { |o| serialized_block(o) },
        entityMap: {}
      }.to_json
    end

    def gif_block(url:, text:)
      {
        key: keygen,
        text: text.to_s,
        type: "recorded-video",
        depth: 0,
        inlineStyleRanges: [],
        entityRanges: [],
        data: {
          rejectedReason: "",
          secondsLeft: 0,
          fileReady: true,
          paused: false,
          url:,
          recording: false,
          granted: true,
          loading: false,
          direction: "center"
        }
      }
    end

    def photo_block(url:, text:, w: nil, h: nil)
      data_options = {}
      if w.present? && h.present?
        data_options = {
          aspect_ratio: get_aspect_ratio(w.to_f, h.to_f),
          width: w.to_i,
          height: h.to_i
        }
      end
      {
        key: keygen,
        text: text.to_s,
        type: "image",
        depth: 0,
        inlineStyleRanges: [],
        entityRanges: [],
        data: {
          caption: text.to_s,
          forceUpload: false,
          url:,
          width: 100,
          height: 100,
          loading_progress: 0,
          selected: false,
          loading: true,
          file: {},
          direction: "center"
        }.merge(data_options)
      }
    end

    def file_block(url:, text:)
      {
        key: keygen,
        text: text.to_s,
        type: "file",
        depth: 0,
        inlineStyleRanges: [],
        entityRanges: [],
        data: {
          caption: text.to_s,
          forceUpload: false,
          url:,
          loading_progress: 0,
          selected: false,
          loading: true,
          file: {},
          direction: "center"
        }
      }
    end

    def serialized_block(text)
      {
        key: keygen,
        text: text.to_s,
        type: "unstyled",
        depth: 0,
        inlineStyleRanges: [],
        entityRanges: [],
        data: {}
      }
    end

    def get_aspect_ratio(w, h)
      maxWidth = 1000
      maxHeight = 1000
      ratio = 0
      width = w # Current image width
      height = h # Current image height

      # Check if the current width is larger than the max
      if width > maxWidth
        ratio = maxWidth / width # get ratio for scaling image
        height *= ratio # Reset height to match scaled image
        width *= ratio # Reset width to match scaled image

        # Check if current height is larger than max
      elsif height > maxHeight
        ratio = maxHeight / height # get ratio for scaling image
        width *= ratio # Reset width to match scaled image
        height *= ratio # Reset height to match scaled image
      end

      fill_ratio = (height / width) * 100
      { width:, height:, ratio: fill_ratio }
      # console.log result
    end

    def direct_upload(file:, filename:, content_type:)
      blob = ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename:,
        content_type:,
        identify: false
      )
      {
        url: Rails.application.routes.url_helpers.rails_blob_path(blob)
      }.merge!(ActiveStorage::Analyzer::ImageAnalyzer::ImageMagick.new(blob).metadata)
    end

    def find_channel(id)
      ConversationPartChannelSource.find_by(
        provider: self.class::PROVIDER,
        message_source_id: id
      )
    end

    def process_read(id)
      conversation_part_channel = find_channel(id)
      return if conversation_part_channel.blank?

      conversation_part_channel.conversation_part.read!
    end

    def build_conn
      Faraday.new request: {
        params_encoder: Faraday::FlatParamsEncoder
      }
    end

    def find_conversation_by_channel(provider, channel)
      conversation = @package
                     .app
                     .conversations
                     .joins(:conversation_channels)
                     .where(
                       "conversation_channels.provider =? AND
        conversation_channels.provider_channel_id =?",
                       provider, channel
                     ).first
    end

    def add_participant(user_data, provider)
      app = @package.app

      if user_data

        profile_data = {
          name: "#{user_data['first_name']} #{user_data['last_name']}"
        }

        data = {
          properties: profile_data
        }

        external_profile = app.external_profiles.find_by(
          provider:,
          profile_id: user_data["id"]
        )

        participant = external_profile&.app_user

        ## todo: check user for this & previous conversation
        if participant.blank?
          participant = app.add_anonymous_user(data)
          participant.external_profiles.create(
            provider:,
            profile_id: user_data["id"]
          )
        end

        participant
      end
    end
  end
end
