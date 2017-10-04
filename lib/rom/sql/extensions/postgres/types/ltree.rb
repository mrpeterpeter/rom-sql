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

        TypeExtensions.register(ROM::SQL::Types::PG::Array('ltree')) do
          CONTAIN_ANY_LTEXTQUERY = ["(".freeze, " @ ".freeze, ")".freeze].freeze

          def contain_any_ltextquery(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(CONTAIN_ANY_LTEXTQUERY, expr, query))
          end

          private

          def custom_sql_expr(string, expr, query)
            Sequel::SQL::PlaceholderLiteralString.new(string, [expr, query])
          end
        end

        TypeExtensions.register(LTree) do
          ASCENDANT = ["(".freeze, " @> ".freeze, ")".freeze].freeze
          DESCENDANT = ["(".freeze, " <@ ".freeze, ")".freeze].freeze
          MATCH_ANY = ["(".freeze, " ? ".freeze, ")".freeze].freeze
          MATCH_LTEXTQUERY = ["(".freeze, " @ ".freeze, ")".freeze].freeze
          FIRST_MATCH = ["(".freeze, " ?~ ".freeze, ")".freeze].freeze

          def match(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: Sequel::SQL::BooleanExpression.new(:'~', expr, query))
          end

          def match_any(type, expr, query)
            array = build_array_query(query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(MATCH_ANY, expr, array))
          end

          def match_ltextquery(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(MATCH_LTEXTQUERY, expr, query))
          end

          def contain_descendant(type, expr, query)
            array = build_array_query(query, 'ltree')
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(DESCENDANT, expr, array))
          end

          def descendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(DESCENDANT, expr, query))
          end

          def contain_ascendant(type, expr, query)
            array = build_array_query(query, 'ltree')
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(ASCENDANT, expr, array))
          end

          def ascendant(type, expr, query)
            Attribute[SQL::Types::Bool].meta(sql_expr: custom_sql_expr(ASCENDANT, expr, query))
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
      end
    end
  end
end
