require 'test/unit'
require 'yarv2llvm'

class Foo
  def initialize
    @bar = 10
  end
end

class CompileTests < Test::Unit::TestCase
#=begin
  def test_fib
    YARV2LLVM::compile(<<-EOS)
def fib(n)
  if n < 2 then
    1
  else
    fib(n - 1) + fib(n - 2)
  end
end
EOS
    assert_equal(fib(35), 14930352)
  end

  def test_array
    YARV2LLVM::compile(<<-EOS)
def arr(n)
  b = []
  a = []
  a[0] = 0
  a[1] = 1
  a[2] = 4
  a[3] = 9
  b[0] = 1.0
  b[1] = 2.0
  b[2] = 3.0
  b[3] = 4.0
  b[0] = b[n]
  b[n]
end
EOS

   assert_equal(arr(0), 1.0)
   assert_equal(arr(1), 2.0)
   assert_equal(arr(2), 3.0)
   assert_equal(arr(3), 4.0)
  end

  def test_hash
    YARV2LLVM::compile(<<-EOS)
def hasht(n)
  b = Hash.new
  a = Hash.new
  a[0] = 0
  a[1] = 1
  a[2] = 4
  a[3] = 9
  b[0] = 1.0
  b[1] = 2.0
  b[2] = 3.0
  b[3] = 4.0
  b[0] = b[n]
  b[n]
end
EOS

   assert_equal(hasht(0), 1.0)
   assert_equal(hasht(1), 2.0)
   assert_equal(hasht(2), 3.0)
   assert_equal(hasht(3), 4.0)
  end

  def test_array2
    YARV2LLVM::compile(<<-EOS)
def arr2(a)
  a[0] = 1.0
  a
end

def arr1()
  a = []
  arr2(a)
  b = "abc"
  a[1] = 41.0
  a[0] + a[1]
end

EOS
   assert_equal(arr1, 42.0)
  end

  def test_double
    YARV2LLVM::compile(<<-EOS)
def dtest(n)
  (Math.sqrt(n) * 2.0 + 1.0) / 3.0
end
EOS
   assert_equal(dtest(2.0), (Math.sqrt(2.0) * 2.0 + 1.0) / 3.0)
 end

  def test_argument_order
#    YARV2LLVM::compile(<<-EOS, {:disasm => true, :optimize=>false})
    YARV2LLVM::compile(<<-EOS, {})
def targorder(x, y, z)
  p "foo"
  p x
  x - (y - z) + 0
end
EOS
   assert_equal(targorder(10, 8, 2), 4)
 end

  def test_while
    YARV2LLVM::compile(<<-EOS)
def while_test(n)
  i = 0
  r = 0
  while i < n do
    i = i + 1
    r = r + i
  end
  r
end
EOS
   assert_equal(while_test(10), 55)
 end

  def test_dup_instruction
    YARV2LLVM::compile(<<-EOS)
def dup(n)
  n = n + 0
  a = n
end
EOS
   assert_equal(dup(10), 10)
 end

  def arru(n)
    ((n + n) * n - n) % ((n + n * n) / n)
  end

  def test_arithmetic
    YARV2LLVM::compile(<<-EOS)
def ari(n)
  ((n + n) * n - n) % ((n + n * n) / n) + 0
end

def arf(n)
  ((n + n) * n - n) % ((n + n * n) / n) + 0.0
end
EOS
   assert_equal(ari(10), arru(10))
   assert_equal(arf(10.0), arru(10.0))
 end

  def arru2(n)
    (n ** 2)
  end

  def test_arithmetic2
    YARV2LLVM::compile(<<-EOS, {})
#def ari2(n)
#  n = n + 0
#  (n.to_f ** 2.0)
#end

def arf2(n)
   n = n + 0.0
  (n ** 2.0)
end
EOS

#   assert_equal(ari2(10), arru2(10))
   assert_equal(arf2(10.0), arru2(10.0))
 end

 def test_compare
   YARV2LLVM::compile(<<-EOS)
def compare(n, m)
  n = n + 0
  m = m + 0
  ((n < m) ? 1 : 0) +
  ((n <= m) ? 2 : 0) +
  ((n > m) ? 4 : 0) +
  ((n >= m) ? 8 : 0)
end
EOS
   assert_equal(compare(0, 1), 3)
   assert_equal(compare(1, 1), 10)
   assert_equal(compare(1, 0), 12)
 end

 def test_forward_call
   YARV2LLVM::compile(<<-EOS)
def f1(n)
  f2(n + 0.5) 
end

def f2(n)
  n
end
EOS
   assert_equal(f1(1.0), 1.5)
 end

 def test_require
   YARV2LLVM::compile(<<-EOS)
require 'sample/e-aux'
EOS
   assert(compute_e[0], 2)
 end


 def test_send_with_block
   # This test don't move when optimize => true
   # This resason is optimizer tries to ilining calling function pointer
   # as argument. When pass two different function pointer as argument ,
   # optimizer crashed.
#   YARV2LLVM::compile(<<-EOS, {:optimize => false})
   YARV2LLVM::compile(<<-EOS, {})
class Fixnum
  def times
    j = 0
    while j < self
      yield j
      j = j + 1
    end
    0
  end
end

def send_with_block(n)
  a = 0
  n = n + 0
  n.times do |i|
    a = a + i
  end
  a
end

class Fixnum
  def send_with_block_fixnum
    a = 0
    self.times do |i|
      a = a + i
    end
    a
  end
end

def send_with_block_2(n)
  n = n + 0
  n.send_with_block_fixnum
end


EOS
    assert_equal(send_with_block(100), 4950)
#    assert_equal(send_with_block2(100), 4950)
  end

  def test_string
    YARV2LLVM::compile(<<-EOS)
def tstring
  a = "Hell world"
  a
end
EOS

    assert_equal(tstring, "Hell world")
  end

  def test_p_method
    YARV2LLVM::compile(<<-EOS)
def tpmethod
  p "Hell world"
  p 1
  p 1.1
  a = []
  a[0] = 1
  a[1] = 10
  a[2] = 11
  p a
end
EOS
   assert_equal(tpmethod, [1, 10, 11])
  end

  def test_2arg_func
    YARV2LLVM::compile(<<-EOS)
      def div1(x, y)
        x / y
      end

      def div2(x)
        x = x + 0
        div1(x, 10)
      end
EOS
   assert_equal(div2(100), 10)
  end

  def test_inited_array
    YARV2LLVM::compile(<<-EOS)
def tinitarray
  a = [[1, 10, 11]]
end
EOS
   assert_equal(tinitarray, [[1, 10, 11]])
  end

  def test_nested_array
    YARV2LLVM::compile(<<-EOS)
def tnestedarray
  a = []
  a[0] = []
  a[0][0] = 1
  a[1] = []
  a[1][0] = 2
  a
end
EOS
   assert_equal(tnestedarray, [[1], [2]])
  end

  def test_gc_test
    YARV2LLVM::compile(<<-EOS)
def tgc
  i = 320000
  b = [1]
  while i > 0
    a = [1, 2, 3, 4, 5, 7, 8]
    c = [1, 2, 3, 4]
    i = i - 1
  end
  b
end
EOS
   GC::Profiler.enable
   assert_equal(tgc, [1])
   GC::Profiler.report
  end

  def test_iv1
    YARV2LLVM::compile(<<-EOS)
class Foo
  def test
    a = @bar
    @bar = 20
    @bar + a
  end
end

def ivtest1(obj)
  obj.test + 3
end
EOS
   assert_equal(ivtest1(Foo.new), 33)
  end

  def test_newtest
    YARV2LLVM::compile(<<-EOS)
class Foo
  def test2
    @bar = 10
    @bar
  end
end

def newtest
  a = Foo.new
  a.test2 + 3
end
EOS
   assert_equal(newtest, 13)
  end

  def test_array_each
    YARV2LLVM::compile(<<-EOS)
def tarray_each  
  rc = 0
  a = [1, 2, 4, 8, 16]
  a.each do |i|
    p i
    rc = rc + i
  end
  rc
end
EOS
    assert_equal(tarray_each, 31)
  end

  def test_upto
    YARV2LLVM::compile(<<-EOS)
def tarray_upto
  rc = 0
  a = [1, 2, 4, 8, 16]
  0.upto(a.size - 1) do |i|
    rc = rc + a[i]
  end
  rc
end
EOS
    assert_equal(tarray_upto, 31)
  end

  def test_return1
#    YARV2LLVM::compile(<<-EOS, {:dump_yarv => true})
    YARV2LLVM::compile(<<-EOS, {})
def treturn(f)
  if f == 1 then
    return 2
  elsif f == 2 then
    a = 3
    return 3
  else
    a = 4
  end
end
EOS
    assert_equal(treturn(1), 2)
    assert_equal(treturn(2), 3)
    assert_equal(treturn(3), 4)
  end

  def test_array_each2
#    YARV2LLVM::compile(<<-EOS, {:func_signature => true})
    YARV2LLVM::compile(<<-EOS)
def tarray_each2
  rc = 0
  a = [1, 2, 4, 8, 16]
  a.each do |i|
    a.each do |j|
      rc = rc + i
    end
  end
  rc
end
EOS
    assert_equal(tarray_each2, 155)
  end

  def test_print1
#    YARV2LLVM::compile(<<-EOS, {:func_signature => true})
    YARV2LLVM::compile(<<-EOS)
def tprint1(n)
  print "The value is "
  print n
  print "\n"
end
EOS
    assert_equal(tprint1("abc"), nil)
  end

  def test_print2
#    YARV2LLVM::compile(<<-EOS, {:func_signature => true})
#    YARV2LLVM::compile(<<-EOS, {:disasm => true})
    YARV2LLVM::compile(<<-EOS)
def tprint2(n)
  print "The value is ", n, "\n"
end
EOS
    assert_equal(tprint2("foo"), nil)
  end

  def test_sprintf
    YARV2LLVM::compile(<<-EOS)
def tsprintf(n)
  sprintf "The value is %p", n
end
EOS
    assert_equal(tsprintf("foo"), "The value is \"foo\"")
  end

  def test_porcess_times
    YARV2LLVM::compile(<<-EOS)
def tprocesstimes
  times = Process.times
  p times
  p times[0]
  nil
end
EOS
   assert_equal(tprocesstimes, nil)
end

  def test_embedded_string
#    YARV2LLVM::compile(<<-'EOS', {:dump_yarv=>true})
    YARV2LLVM::compile(<<-'EOS', {})
def tembeddedstring
  n = 1
  b = 1.0
  c = "bar"
  "Embedded string is #{n}, #{b} and #{c}"
end
EOS
  n = 1
  b = 1.0
  c = "bar"
  assert_equal(tembeddedstring, "Embedded string is #{n}, #{b} and #{c}")
end
#=end

=begin
  def test_thread
    YARV2LLVM::compile(<<-EOS)
def tthread
  Thread.new {
    10.times do |i|
      p i
    end
    nil
  }
  print "END"
  10.times do |i|
    puts sprintf("foo%d", i)
  end
  sleep(2)
  nil
end
EOS
   assert_equal(tthread, nil)
end
=end

  def test_case
    YARV2LLVM::compile(<<-EOS)
  
  def t_case(n)
    case n
    when :foo
      1
    when 2
      2
    when 2.2
      3
    else
      4
    end
  end
EOS

    assert_equal(t_case(:foo), 1)
    assert_equal(t_case(2), 2)
    assert_equal(t_case(2.2), 3)
    assert_equal(t_case("foo"), 4)
  end


# I can't pass this test yet.

  def test_complex_type
    YARV2LLVM::compile(<<-EOS, {:optimize => false})
#    YARV2LLVM::compile(<<-EOS, {})
        def t_complex_str(arr)
#          arr[0]
           arr
        end

        def t_complex_arr(arr)
          arr[0]
        end

        def t_complex(f)
          if f == 0 then
            t_complex_str("abc")
            0
          else
            a = []
            a[0] = 1
            a[1] = 2
            t_complex_arr(a)
          end
        end
EOS
     assert_equal(t_complex(1), 1)
   end

  def test_range_to_a
#    YARV2LLVM::compile(<<-EOS, {:disasm => true})
    YARV2LLVM::compile(<<-EOS, {})
        def t_range_to_a
          (1..10).to_a
        end
EOS
     assert_equal(t_range_to_a, (1..10).to_a)
   end
end
