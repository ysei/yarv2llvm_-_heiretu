#
# Test for unsafe extention
#
require 'test/unit'
require 'yarv2llvm'
class UnsafeTests < Test::Unit::TestCase

  def test_unsafe
    YARV2LLVM::compile(<<-EOS, {:disasm => true, :dump_yarv => true, :optimize=> true})
def tunsafe
#  rbasic = LLVM::struct([RubyHelpers::VALUE, LLVM::Type::Int32Ty])
  type = LLVM::struct([RubyHelpers::VALUE, LLVM::Type::Int32Ty, RubyHelpers::VALUE, RubyHelpers::VALUE])
  a = [:a, :b]
  foo = YARV2LLVM::LLVMLIB::unsafe(a, type)
  YARV2LLVM::LLVMLIB::safe(foo[2])
end
EOS
    assert_equal(tunsafe, :a)
  end

  def test_define_external_function
    YARV2LLVM::compile(<<-EOS, {:disasm => true, :dump_yarv => true, :optimize=> true, :func_signature => true})
def tdefine_external_function
  value = RubyHelpers::VALUE
  int32ty = LLVM::Type::Int32Ty
  type = LLVM::function(value, [int32ty])
  YARV2LLVM::LLVMLIB::define_external_function(:rb_ary_new2, 
                                               'rb_ary_new2', 
                                               type)
  
  siz = YARV2LLVM::LLVMLIB::unsafe(2, int32ty)
  rb_ary_new2(siz)
end
EOS
    assert_equal(tdefine_external_function, [])
  end
end
