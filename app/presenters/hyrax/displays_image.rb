require 'iiif_manifest'

module Hyrax
  # This gets mixed into FileSetPresenter in order to create
  # a canvas on a IIIF manifest
  module DisplaysImage
    extend ActiveSupport::Concern

    # Creates a display image only where FileSet is an image.
    #
    # @return [IIIFManifest::DisplayImage] the display image required by the manifest builder.
    def display_image
      return nil unless ::FileSet.exists?(id) && solr_document.image? && current_ability.can?(:read, id)

      latest_file_id = lookup_original_file_id

      return nil unless latest_file_id

      url = Hyrax.config.iiif_image_url_builder.call(
        latest_file_id,
        request.base_url,
        Hyrax.config.iiif_image_size_default,
        format: image_format(alpha_channels)
      )

      # @see https://github.com/samvera-labs/iiif_manifest
      IIIFManifest::DisplayImage.new(url,
                                     format: image_format(alpha_channels),
                                     width: width,
                                     height: height,
                                     iiif_endpoint: iiif_endpoint(latest_file_id))
    end

    private

      def iiif_endpoint(file_id)
        return unless Hyrax.config.iiif_image_server?
        IIIFManifest::IIIFEndpoint.new(
          Hyrax.config.iiif_info_url_builder.call(file_id, request.base_url),
          profile: Hyrax.config.iiif_image_compliance_level_uri
        )
      end

      def image_format(channels)
        channels&.include?('rgba') ? 'png' : 'jpg'
      end

      def lookup_original_file_id
        result = original_file_id
        if result.blank?
          Rails.logger.warn "original_file_id for #{id} not found, falling back to Fedora."
          result = Hyrax::VersioningService.versioned_file_id ::FileSet.find(id).original_file
        end
        result
      end
  end
end
