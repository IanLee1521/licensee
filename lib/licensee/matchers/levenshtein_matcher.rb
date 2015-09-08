class Licensee
  class LevenshteinMatcher < Matcher

    # Return the first potential license that is more similar than the confidence threshold
    def match
      return @match if defined? @match
      @match = potential_licenses.find do |license|

        # If we know the license text contains the license name or nickname,
        # bail early unless the file we're checking contains it.
        # Guards against OSL & AFL confusion. See https://github.com/benbalter/licensee/issues/50
        next if license.body_includes_name? && !includes_license_name?(license)
        next if license.body_includes_nickname? && !includes_license_nickname?(license)

        similarity(license) >= Licensee.confidence_threshold
      end
    end

    # Sort all licenses, in decending order, by difference in length to the file
    # Difference in lengths cannot exceed the file's length * the confidence threshold / 100
    def potential_licenses
      @potential_licenses ||= begin
        licenses = Licensee.licenses(:hidden => true)
        licenses = licenses.select do |license|
          license.body_normalized && length_delta(license) <= max_delta
        end
        licenses.sort_by { |l| length_delta(l) }
      end
    end

    # Calculate the difference between the file length and a given license's length
    def length_delta(license)
      (file_length - license.body_normalized.length).abs
    end

    # Maximum possible difference between file length and license length
    # for a license to be a potential license to be matched
    def max_delta
      @max_delta ||= (file_length * (Licensee.confidence_threshold.to_f / 100.to_f ))
    end

    # Confidence that the matched license is a match
    def confidence
      @confidence ||= match ? similarity(match) : 0
    end

    private

    # Length of the file, normalized to strip whitespace
    def file_length
      @file_length ||= file.content_normalized.length.to_f
    end

    # Calculate percent changed between file and potential license
    def similarity(license)
      100 * (file_length - distance(license)) / file_length
    end

    # Calculate the levenshtein distance between file and license
    # Note: We used content/body normalized because white space and capitalization
    # isn't legally significant in this context. Fewer characters lets levenshtein
    # work faster. As long as they both undergo the same transformation, should match.
    def distance(license)
      Levenshtein.distance(license.body_normalized, file.content_normalized).to_f
    end

    def includes_license_name?(license)
      file.content_normalized.include?(license.name_without_version.downcase)
    end

    def includes_license_nickname?(license)
      license.nickname && file.content_normalized.include?(license.nickname.downcase)
    end
  end
end
