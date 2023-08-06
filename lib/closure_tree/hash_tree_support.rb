module ClosureTree
  module HashTreeSupport
    def default_tree_scope(scope, limit_depth = nil)
        # Deepest generation, within limit, for each descendant
        # NOTE: Postgres requires HAVING clauses to always contains aggregate functions (!!)
        having_clause = limit_depth ? "HAVING MAX(generations) <= #{limit_depth - 1}" : ''
        filter = scope.select(model_class.primary_key).to_sql
        where_clause = scope.where_clause.any? ? "WHERE descendant_id IN (#{filter})" : ''
        generation_depth = <<-SQL.squish
          INNER JOIN (
            SELECT descendant_id, MAX(generations) as depth
            FROM #{quoted_hierarchy_table_name}
            #{where_clause}
            GROUP BY descendant_id
            #{having_clause}
          ) #{ t_alias_keyword } generation_depth
            ON #{quoted_table_name}.#{model_class.primary_key} = generation_depth.descendant_id
        SQL
        scope.joins(generation_depth)
    end

    def hash_tree(tree_scope, limit_depth = nil)
      limited_scope = limit_depth ? tree_scope.where("#{quoted_hierarchy_table_name}.generations <= #{limit_depth - 1}") : tree_scope
      build_hash_tree(limited_scope)
    end

    # Builds nested hash structure using the scope returned from the passed in scope
    def build_hash_tree(tree_scope)
      node_ids = Set.new(tree_scope.map(&:id))
      index = Hash.new { |h, k| h[k] = {} }

      tree_scope.each_with_object({}) do |node, arranged|
        children = index[node.id]
        index[node.parent_id][node] = children
        arranged[node] = children unless node_ids.include?(node.parent_id)
      end
    end
  end
end
