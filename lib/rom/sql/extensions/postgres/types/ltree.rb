module ROM
  module SQL
    module Postgres
      module Values
        LabelPath = ::Struct.new(:path) do
          def labels
            path.split('.')
          end
        end
      end

      # @api public
      module Types
        # @see https://www.postgresql.org/docs/current/static/ltree.html

        LTree = SQL::Types.define(Values::LabelPath) do
          input do |label_path|
            label_path.path
          end

          output do |label_path|
            Values::LabelPath.new(label_path.to_s)
          end
        end

        module LTreeMethods
          ASCENDANT = ["(".freeze, " @> ".freeze, ")".freeze].freeze
          FIND_ASCENDANT = ["(".freeze, " ?@> ".freeze, ")".freeze].freeze
          DESCENDANT = ["(".freeze, " <@ ".freeze, ")".freeze].freeze
          FIND_DESCENDANT = ["(".freeze, " ?<@ ".freeze, ")".freeze].freeze
          MATCH_ANY = ["(".freeze, " ? ".freeze, ")".freeze].freeze
          MATCH_ANY_LQUERY = ["(".freeze, " ?~ ".freeze, ")".freeze].freeze
          MATCH_LTEXTQUERY = ["(".freeze, " @ ".freeze, ")".freeze].freeze
          MATCH_ANY_LTEXTQUERY = ["(".freeze, " ?@ ".freeze, ")".freeze].freeze

          def match(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Sequel::SQL::BooleanExpression.new(:'~', expr, query))
          end

          def match_any(type, expr, query)
            array = build_array_query(query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(MATCH_ANY, expr, array))
          end

          private

          def custom_sql_expr(string, expr, query)
            Sequel::SQL::PlaceholderLiteralString.new(string, [expr, query])
          end

          def build_array_query(query, array_type = 'lquery')
            case query
            when Sequel::Postgres::PGArray
              if query.array_type == array_type
                query
              else
                query.array_type = array_type
                query
              end
            when Array
              ROM::SQL::Types::PG::Array(array_type)[query]
            when String
              ROM::SQL::Types::PG::Array(array_type)[query.split(',')]
            end
          end
        end

        TypeExtensions.register(ROM::SQL::Types::PG::Array('ltree')) do
          include LTreeMethods

          def contain_any_ltextquery(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::MATCH_LTEXTQUERY, expr, query))
          end

          def contain_ancestor(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::ASCENDANT, expr, query))
          end

          def contain_descendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::DESCENDANT, expr, query))
          end

          def find_ancestor(type, expr, query)
            Attribute[LTree].meta(sql_expr: custom_sql_expr(LTreeMethods::FIND_ASCENDANT, expr, query))
          end

          def find_descendant(type, expr, query)
            Attribute[LTree].meta(sql_expr: custom_sql_expr(LTreeMethods::FIND_DESCENDANT, expr, query))
          end

          def match_any_lquery(type, expr, query)
            Attribute[LTree].meta(sql_expr: custom_sql_expr(LTreeMethods::MATCH_ANY_LQUERY, expr, query))
          end

          def match_any_ltextquery(type, expr, query)
            Attribute[LTree].meta(sql_expr: custom_sql_expr(LTreeMethods::MATCH_ANY_LTEXTQUERY, expr, query))
          end
        end

        TypeExtensions.register(LTree) do
          include LTreeMethods

          def match_ltextquery(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::MATCH_LTEXTQUERY, expr, query))
          end

          def contain_descendant(type, expr, query)
            array = build_array_query(query, 'ltree')
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::DESCENDANT, expr, array))
          end

          def descendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::DESCENDANT, expr, query))
          end

          def contain_ascendant(type, expr, query)
            array = build_array_query(query, 'ltree')
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::ASCENDANT, expr, array))
          end

          def ascendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(LTreeMethods::ASCENDANT, expr, query))
          end

          def +(type, expr, other)
            other_value = case other
                          when Values::LabelPath
                            other
                          else
                            Values::LabelPath.new(other)
                          end
            Attribute[LTree].meta(sql_expr: Sequel::SQL::StringExpression.new(:'||', expr, other_value.path))
          end
        end
      end
    end
  end
end
