require 'perforce2svn/mapping/lexer'
require 'perforce2svn/logging'

module Perforce2Svn
  module Mapping

    class MappingConfiguration
      attr_accessor :branch_mappings, :commands

      def initialize
        @branch_mappings = []
        @commands = []
      end
    end

    class Parser
      include Perforce2Svn::Logging

      attr_reader :mapping

      def initialize(content, live_path)
        if not content.respond_to? :readlines
          raise ArgumentError, "The content must respond to 'readlines'"
        end

        @lexer = Lexer.new(content)
        @live_path = live_path
        
        if not @live_path.nil? and not @live_path =~ /\/$/
          @live_path << '/'
        end
      end

      def parse!
        parse_content
        if parse_failed?
          raise MappingParserError, "Unable to parse mapping file"
        end
        @mapping
      end

      def parse_content
        @mapping = MappingConfiguration.new
        @failed = false
        @lexer.each do |tok|
          handle(tok)
        end
      end

      def parse_failed?
        @failed
      end

      private
      def handle(tok)
        action = tok[0].gsub(/-/, '_')
        if private_methods.include? action
          send(action, tok)
        else
          log.error "(line: #{tok.line}) Unknown directive: '#{tok[0]}'"
          @failed = true
        end
      end

      def add(tok)
        return if not args_ok?(1, tok)
        @mapping.commands << Add.new(to_svn(tok, 1), to_live(tok, 1))
      end
        
      def copy(tok)
        return if not args_ok?(2, tok)
        @mapping.commands << Copy.new(to_svn(tok, 1), to_svn(tok, 2))
      end

      def remove(tok)
        return if not args_ok?(1, tok)
        @mapping.commands << Remove.new(to_svn(tok, 1))
      end

      def mkdir(tok)
        return if not args_ok?(1, tok)
        @mapping.commands << Mkdir.new(to_svn(tok, 1))
      end

      def move(tok)
        return if not args_ok?(2, tok)
        @mapping.commands << Move.new(to_svn(tok, 1))
      end

      def update(tok)
        return if not args_ok?(1, tok)
        @mapping.commands << Update.new(to_svn(tok, 1), to_live(tok, 1))
      end

      def migrate(tok)
        return if not args_ok?(2, tok)
        
        p4_path = tok[1]
        p4_path << '/' if not p4_path[-1].chr == '/'
        svn_path = to_svn(tok, 2)
        svn_path << '/' if not svn_path[-1].chr == '/'

        if not p4_path =~ %r|^//([^/]+/?)*$|
          log.error "(line #{tok.line}) Perforce path was malformed: '#{p4_path}'"
          @failed = true
        end

        if not svn_path =~ %r|^/?([^/]+/?)*$|
          log.error "(line #{tok.line}) Subversion path was malformed: '#{svn_path}'"
          @failed = true
        end

        @mapping.branch_mappings << BranchMapping.new(p4_path, svn_path)
      end

      def svn_prefix(tok)
        return if not args_ok?(1, tok)
        if not tok[1] =~ /^\//
          log.error "(line: #{tok.line}) 'svn-prefix' directive must start with a '/'"
          @failed = true
        else
          @svn_prefix = tok[1]
          if not @svn_prefix =~ /\/$/
            @svn_prefix << '/'
          end
        end
      end

      def args_ok?(required_count, tok)
        if tok.arg_count != required_count
          log.error "(line: #{tok.line}) '#{tok[0]}' requires #{required_count} argument(s), but found #{tok.arg_count}"
          @failed = true
          return false
        end
        return true
      end

      def to_svn(tok, index)
        if @svn_prefix.nil? and not tok[index] =~ /^\//
          log.error "(line: #{tok.line}) No 'svn-prefix' defined, but a relative SVN path was used"
          @failed = true
          nil
        else
          tok[index]
        end
      end

      def to_live(tok, index)
        if @live_path.nil?
          log.error "(line: #{tok.line}) The command '#{tok[0]}' requires a live path, but none was given."
          @failed = true
          nil
        else
          "#{@live_path}/#{tok[index]}"
        end
      end
    end # Mapping


    class Add
      attr_reader :svn_path, :live_path
      def initialize(svn_path, live_path)
        @svn_path = svn_path
        @live_path = live_path
      end
    end

    class Copy
      attr_reader :svn_from, :svn_to
      def initialize(svn_from, svn_to)
        @svn_from = svn_from
        @svn_to = svn_to
      end
    end

    class Mkdir
      attr_reader :svn_path
      def initialize(svn_path)
        @svn_path = svn_path
      end
    end

    class Move
      attr_reader :svn_from, :svn_to
      def initialize(svn_from, svn_to)
        @svn_from = svn_from
        @svn_to = svn_to
      end
    end

    class Update
      attr_reader :svn_path, :live_path
      def initialize(svn_path, live_path)
        @svn_path = svn_path
        @live_path = live_path
      end
    end

    class Remove
      attr_reader :svn_path
      def initialize(svn_path)
        @svn_path = svn_path
      end
    end

    class BranchMapping
      attr_reader :p4_path, :svn_path

      def initialize(p4_path, svn_path)
        @p4_path = p4_path
        @svn_path = svn_path
      end

      def p4_dotted
        @p4_dotted + '...'
      end

      def matches?(other_p4_path)
        (other_p4_path =~ /^#{p4_path}/) != nil
      end

      def to_svn_path(other_p4_path)
        other_p4_path.gsub(p4_path, svn_path).gsub("%40", "@").gsub("%23", "#").gsub("%2a", "*").gsub("%25", "%")
      end
    end
  end
end
