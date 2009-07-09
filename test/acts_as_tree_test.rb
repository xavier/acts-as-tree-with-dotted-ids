require 'test/unit'

require 'rubygems'
require 'active_record'

$:.unshift File.dirname(__FILE__) + '/../lib'

require 'active_record/acts/tree_with_dotted_ids'

require File.dirname(__FILE__) + '/../init'

class Test::Unit::TestCase
  def assert_queries(num = 1)
    $query_count = 0
    yield
  ensure
    assert_equal num, $query_count, "#{$query_count} instead of #{num} queries were executed."
  end

  def assert_no_queries(&block)
    assert_queries(0, &block)
  end
end

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

# AR keeps printing annoying schema statements
$stdout = StringIO.new

def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :mixins do |t|
      t.column :type, :string
      t.column :parent_id, :integer
      t.column :dotted_ids, :string
      t.column :name, :string
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Mixin < ActiveRecord::Base
end

class TreeMixin < Mixin 
  acts_as_tree_with_dotted_ids :foreign_key => "parent_id", :order => "id"
end

class TreeMixinWithoutOrder < Mixin
  acts_as_tree_with_dotted_ids :foreign_key => "parent_id"
end

class RecursivelyCascadedTreeMixin < Mixin
  acts_as_tree_with_dotted_ids :foreign_key => "parent_id"
  has_one :first_child, :class_name => 'RecursivelyCascadedTreeMixin', :foreign_key => :parent_id
end

class TreeTest < Test::Unit::TestCase
  
  def setup
    setup_db
    @root1 = TreeMixin.create!
    @root_child1 = TreeMixin.create! :parent_id => @root1.id
    @child1_child = TreeMixin.create! :parent_id => @root_child1.id
    @root_child2 = TreeMixin.create! :parent_id => @root1.id
    @root2 = TreeMixin.create!
    @root3 = TreeMixin.create!
  end

  def teardown
    teardown_db
  end

  def test_children
    assert_equal @root1.children, [@root_child1, @root_child2]
    assert_equal @root_child1.children, [@child1_child]
    assert_equal @child1_child.children, []
    assert_equal @root_child2.children, []
  end

  def test_parent
    assert_equal @root_child1.parent, @root1
    assert_equal @root_child1.parent, @root_child2.parent
    assert_nil @root1.parent
  end

  def test_delete
    assert_equal 6, TreeMixin.count
    @root1.destroy
    assert_equal 2, TreeMixin.count
    @root2.destroy
    @root3.destroy
    assert_equal 0, TreeMixin.count
  end

  def test_insert
    @extra = @root1.children.create

    assert @extra

    assert_equal @extra.parent, @root1

    assert_equal 3, @root1.children.size
    assert @root1.children.include?(@extra)
    assert @root1.children.include?(@root_child1)
    assert @root1.children.include?(@root_child2)
  end

  def test_ancestors
    assert_equal [], @root1.ancestors
    assert_equal [@root1], @root_child1.ancestors
    assert_equal [@root_child1, @root1], @child1_child.ancestors
    assert_equal [@root1], @root_child2.ancestors
    assert_equal [], @root2.ancestors
    assert_equal [], @root3.ancestors
  end

  def test_root
    assert_equal @root1, TreeMixin.root
    assert_equal @root1, @root1.root
    assert_equal @root1, @root_child1.root
    assert_equal @root1, @child1_child.root
    assert_equal @root1, @root_child2.root
    assert_equal @root2, @root2.root
    assert_equal @root3, @root3.root
  end

  def test_roots
    assert_equal [@root1, @root2, @root3], TreeMixin.roots
  end

  def test_siblings
    assert_equal [@root2, @root3], @root1.siblings
    assert_equal [@root_child2], @root_child1.siblings
    assert_equal [], @child1_child.siblings
    assert_equal [@root_child1], @root_child2.siblings
    assert_equal [@root1, @root3], @root2.siblings
    assert_equal [@root1, @root2], @root3.siblings
  end

  def test_self_and_siblings
    assert_equal [@root1, @root2, @root3], @root1.self_and_siblings
    assert_equal [@root_child1, @root_child2], @root_child1.self_and_siblings
    assert_equal [@child1_child], @child1_child.self_and_siblings
    assert_equal [@root_child1, @root_child2], @root_child2.self_and_siblings
    assert_equal [@root1, @root2, @root3], @root2.self_and_siblings
    assert_equal [@root1, @root2, @root3], @root3.self_and_siblings
  end           
end

class TreeTestWithEagerLoading < Test::Unit::TestCase
  
  def setup 
    teardown_db
    setup_db
    @root1 = TreeMixin.create!
    @root_child1 = TreeMixin.create! :parent_id => @root1.id
    @child1_child = TreeMixin.create! :parent_id => @root_child1.id
    @root_child2 = TreeMixin.create! :parent_id => @root1.id
    @root2 = TreeMixin.create!
    @root3 = TreeMixin.create!
    
    @rc1 = RecursivelyCascadedTreeMixin.create!
    @rc2 = RecursivelyCascadedTreeMixin.create! :parent_id => @rc1.id 
    @rc3 = RecursivelyCascadedTreeMixin.create! :parent_id => @rc2.id
    @rc4 = RecursivelyCascadedTreeMixin.create! :parent_id => @rc3.id
  end

  def teardown
    teardown_db
  end
    
  def test_eager_association_loading
    roots = TreeMixin.find(:all, :include => :children, :conditions => "mixins.parent_id IS NULL", :order => "mixins.id")
    assert_equal [@root1, @root2, @root3], roots                     
    assert_no_queries do
      assert_equal 2, roots[0].children.size
      assert_equal 0, roots[1].children.size
      assert_equal 0, roots[2].children.size
    end   
  end
  
  def test_eager_association_loading_with_recursive_cascading_three_levels_has_many
    root_node = RecursivelyCascadedTreeMixin.find(:first, :include => { :children => { :children => :children } }, :order => 'mixins.id')
    assert_equal @rc4, assert_no_queries { root_node.children.first.children.first.children.first }
  end
  
  def test_eager_association_loading_with_recursive_cascading_three_levels_has_one
    root_node = RecursivelyCascadedTreeMixin.find(:first, :include => { :first_child => { :first_child => :first_child } }, :order => 'mixins.id')
    assert_equal @rc4, assert_no_queries { root_node.first_child.first_child.first_child }
  end
  
  def test_eager_association_loading_with_recursive_cascading_three_levels_belongs_to
    leaf_node = RecursivelyCascadedTreeMixin.find(:first, :include => { :parent => { :parent => :parent } }, :order => 'mixins.id DESC')
    assert_equal @rc1, assert_no_queries { leaf_node.parent.parent.parent }
  end 
end

class TreeTestWithoutOrder < Test::Unit::TestCase
  
  def setup                               
    setup_db
    @root1 = TreeMixinWithoutOrder.create!
    @root2 = TreeMixinWithoutOrder.create!
  end

  def teardown
    teardown_db
  end

  def test_root
    assert [@root1, @root2].include?(TreeMixinWithoutOrder.root)
  end
  
  def test_roots
    assert_equal [], [@root1, @root2] - TreeMixinWithoutOrder.roots
  end
end 

class TestDottedIdTree < Test::Unit::TestCase
  
  def setup
    setup_db
    @tree = TreeMixin.create(:name => 'Root')
    @child = @tree.children.create(:name => 'Child')
    @subchild = @child.children.create(:name => 'Subchild')
    @new_root = TreeMixin.create!(:name => 'New Root')
  end
  
  def teardown
    teardown_db
  end
  
  def test_build_dotted_ids
    assert_equal "#{@tree.id}", @tree.dotted_ids
    assert_equal "#{@tree.id}.#{@child.id}", @child.dotted_ids
    assert_equal "#{@tree.id}.#{@child.id}.#{@subchild.id}", @subchild.dotted_ids
  end
  
  def test_ancestor_of
    
    assert @tree.ancestor_of?(@child)
    assert @child.ancestor_of?(@subchild)
    assert @tree.ancestor_of?(@subchild)
    
    assert !@tree.ancestor_of?(@tree)
    assert !@child.ancestor_of?(@child)
    assert !@subchild.ancestor_of?(@subchild)
    
    assert !@child.ancestor_of?(@tree)
    assert !@subchild.ancestor_of?(@tree)
    assert !@subchild.ancestor_of?(@child)
    
  end
  
  def test_descendant_of
    
    assert @child.descendant_of?(@tree)
    assert @subchild.descendant_of?(@child)
    assert @subchild.descendant_of?(@tree)
    
    assert !@tree.descendant_of?(@tree)
    assert !@child.descendant_of?(@child)
    assert !@subchild.descendant_of?(@subchild)
    
    assert !@tree.descendant_of?(@child)
    assert !@child.descendant_of?(@subchild)
    assert !@tree.descendant_of?(@subchild)
    
  end
  
  
  def test_all_children
    
    kids = @tree.all_children
    assert_kind_of Array, kids
    assert kids.size == 2
    assert !kids.include?(@tree)
    assert kids.include?(@child)
    assert kids.include?(@subchild)
    
    kids = @child.all_children
    assert_kind_of Array, kids
    assert kids.size == 1
    assert !kids.include?(@child)
    assert kids.include?(@subchild)
        
    kids = @subchild.all_children
    assert_kind_of Array, kids
    assert kids.empty?
    
  end
  
  def test_rebuild
     
     @tree.parent_id = @new_root.id
     @tree.save
     
     @new_root.reload
     @root = @new_root.children.first
     @child = @root.children.first
     @subchild = @child.children.first
     
     assert_equal "#{@new_root.id}", @new_root.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}", @tree.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}.#{@child.id}", @child.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}.#{@child.id}.#{@subchild.id}", @subchild.dotted_ids
     assert @tree.ancestor_of?(@subchild)
     assert @new_root.ancestor_of?(@tree)
     
     @subchild.parent = @tree
     @subchild.save
        
     assert_equal "#{@new_root.id}", @new_root.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}", @tree.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}.#{@child.id}", @child.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}.#{@subchild.id}", @subchild.dotted_ids
     
     @child.parent = nil
     @child.save!
     
     assert_equal "#{@new_root.id}", @new_root.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}", @tree.dotted_ids
     assert_equal "#{@child.id}", @child.dotted_ids
     assert_equal "#{@new_root.id}.#{@tree.id}.#{@subchild.id}", @subchild.dotted_ids
     
   end
      
   def test_ancestors
    assert @tree.ancestors.empty?
    assert_equal [@tree], @child.ancestors
    assert_equal [@child, @tree], @subchild.ancestors
   end
   
   def test_root     
     assert_equal @tree, @tree.root
     assert_equal @tree, @child.root
     assert_equal @tree, @subchild.root
   end
   
   def test_traverse
     
     traversed_nodes = []
     TreeMixin.traverse { |node| traversed_nodes << node }
     
     assert_equal [@tree, @child, @subchild, @new_root], traversed_nodes
     
   end
   
   def test_rebuild_dotted_ids
     
     TreeMixin.update_all('dotted_ids = NULL')
     assert TreeMixin.find(:all).all? { |n| n.dotted_ids.blank? }
     @subchild.reload
     assert_nil @subchild.dotted_ids
     
     TreeMixin.rebuild_dotted_ids!
     assert TreeMixin.find(:all).all? { |n| n.dotted_ids.present? }
     @subchild.reload
     assert_equal "#{@tree.id}.#{@child.id}.#{@subchild.id}", @subchild.dotted_ids
     
   end
   
   def test_depth
     assert_equal 0, @tree.depth
     assert_equal 1, @child.depth
     assert_equal 2, @subchild.depth
   end
   
end

