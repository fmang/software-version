module SoftwareVersion
  class Version
    include Comparable

    attr_reader :v

    def initialize(raw_version)
      @v = raw_version
    end

    def <=>(other)
      other_tokens = other.is_a?(Version) ? other.tokens : parse(other.to_s)
      tokens.zip(other_tokens) do |left, right|
        cmp = left <=> right
        return cmp if cmp != 0
      end
      0
    end

    def to_s
      @v.to_s
    end

    def to_str
      to_s
    end

    def epoch
      tokens[0].value if tokens[0]&.type == Token::EPOCH
    end

    def major
      version_parts[0]
    end

    def minor
      version_parts[1]
    end

    def patch
      version_parts[2]
    end

    protected

    class Token < Struct.new(:type, :value)
      # Token types. Their value must be ordered such that :
      #
      #     1alpha (PREVERSION)
      #   < 1 (EOV)
      #   < 1-1 (DASH)
      #   < 1+1 (PLUS)
      #   < 1~1 (TILDE)
      #   < 1g (WORD)
      #   < 1_1 (UNDERSCORE)
      #   < 1.1 (DOT)
      #   < 1:1 (EPOCH)
      #
      # COLON, DOT and TILDE are only used as a literal tokens and are stripped
      # from the semantic tokens. Their only use is to separate numbers. Some
      # special words are stripped for the same reason. Thus: 1.1 = 1~1 = 1u1.
      #
      PREVERSION = 10
      EOV = 20 # end of version
      DASH = 30
      PLUS = 31
      TILDE = 32
      COLON = 33
      WORD = 40
      UNDERSCORE = 50
      DOT = 51
      NUMBER = 52
      EPOCH = 60

      def <=>(other)
        cmp = type <=> other.type
        cmp == 0 ? value <=> other.value : cmp
      end
    end

    # Returns an Array of Token. It is fully loaded and cached to boost future
    # comparisons.
    def tokens
      @tokens ||= parse(@v.to_s)
    end

    private

    # Associate characters to their token types. Multiple characters of the
    # same type are grouped together to form a single unit.
    CHARACTERS_TOKEN = {
        '.' => Token::DOT,
        '~' => Token::TILDE,
        '+' => Token::PLUS,
        '-' => Token::DASH,
        ':' => Token::COLON,
        '_' => Token::UNDERSCORE,
        '0' => Token::NUMBER,
        '1' => Token::NUMBER,
        '2' => Token::NUMBER,
        '3' => Token::NUMBER,
        '4' => Token::NUMBER,
        '5' => Token::NUMBER,
        '6' => Token::NUMBER,
        '7' => Token::NUMBER,
        '8' => Token::NUMBER,
        '9' => Token::NUMBER,
      }.tap { |h| h.default = Token::WORD }.freeze

    # Cut the version string into literal tokens, without further
    # interpretation. 1:2.3beta becomes NUMBER COLON NUMBER NUMBER WORD EOV. Returns an Array of Token.
    def lex(version_string)
      tokens = []
      chunk_type = nil
      chunk_value = ''
      commit = ->() {
        case chunk_type
        when nil then return
        when Token::NUMBER then tokens << Token.new(Token::NUMBER, chunk_value.to_i)
        when Token::WORD then tokens << Token.new(Token::WORD, chunk_value.downcase)
        else tokens << Token.new(chunk_type, chunk_value)
        end
        chunk_type = nil
        chunk_value = ''
      }
      version_string.each_char do |c|
        char_type = CHARACTERS_TOKEN[c]
        commit.call if chunk_type != char_type
        chunk_type = char_type
        chunk_value << c
      end
      commit.call
      tokens << Token.new(Token::EOV, nil)
      tokens
    end

    # Return an enumarable of semantic Token from a version string.
    def parse(version_string)
      semantic_tokens = []

      literal_tokens = lex(version_string)
      literal_tokens << nil # Sentinel for each_cons.
      literal_tokens.each_cons(2) do |current, ahead|
        case current.type
        when Token::NUMBER
          # When emitting a zero number followed by a colon, we turn it into
          # an EPOCH so that 1:1 > 2, as most Linux distributions expect.
          if ahead.type == Token::COLON
            semantic_tokens << Token.new(Token::EPOCH, current.value)
          else
            semantic_tokens << current
          end

        # Dots are always dropped because they bear no semantic value.
        when Token::DOT

        # Tildes are ignored unconditionally because they are usually used
        # for preversions without extra semantic meaning.
        when Token::TILDE

        # Underscores are sometimes used to specify subversions on
        # distributions, like el6_7. They’re like dots, so dropped.
        when Token::UNDERSCORE

        # Colon tokens are dropped because their only use is to turn the
        # previous NUMBER into an EPOCH, which is handled by the NUMBER case.
        when Token::COLON

        when Token::WORD
          case current.value
          # Some special words are just fancy ways of making a subversion.
          # Semantically, they are nothing more than dots, so 1u1 = 1.1. Some
          # softwares have versions like 1a, 1b, 1c, so we skip these word
          # tokens only when immediately followed by a number.
          when 'r', 'u', 'p', 'v'
            semantic_tokens << current unless ahead.type == Token::NUMBER
          when 'rev', 'revision', 'update', 'patch'
            # Drop.
          # 52.0a2 is assumed to mean 52.0alpha2, while 52b would be the
          # version before 52c. We distinguish them with the token ahead.
          when 'a', 'b'
            if ahead.type == Token::NUMBER
              semantic_tokens << Token.new(Token::PREVERSION, current.value)
            else
              semantic_tokens << current
            end
          # Non-abbreviated pre-versions may or may not be followed by a
          # number. 1.0alpha < 1.0.
          when 'alpha', 'beta', 'rc'
            semantic_tokens << Token.new(Token::PREVERSION, current.value)
          # Unknown words are left intact.
          else
            semantic_tokens << current
          end

        # Other tokens like + and - are left intact.
        else
          semantic_tokens << current
        end
      end

      normalize(semantic_tokens)
    end

    # Normalize versions by dropping useless zeroes in order to have 1.0.0 = 1.
    # This step is performed after semantic parsing because we want 1.0.r1 ≠
    # 1r1, but also 1.0.noarch = 1.noarch.
    def normalize(tokens)
      new_tokens = []
      held_tokens = []
      tokens.each do |token|
        if token.type == Token::NUMBER
          if token.value == 0
            held_tokens << token
            next
          else
            new_tokens.concat(held_tokens)
          end
        end
        held_tokens.clear
        new_tokens << token
      end
      new_tokens
    end

    # Return the first number sequence in the version as an array of Integer,
    # skipping the epoch.
    def version_parts
      return @version_parts if @version_parts

      parts = []
      tokens.each do |t|
        if t.type == Token::NUMBER
          parts << t.value
        elsif !parts.empty?
          break
        end
      end
      @version_parts = parts
    end
  end

  # Convert the argument to a Version, unless it already is one.
  def Version(version)
    version.is_a?(Version) ? version : Version.new(version)
  end
  module_function :Version
end
