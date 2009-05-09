#!/bin/ruby 
#
#  Traverse YARV and generate Ruby
#

if __FILE__ == $0 then
  require 'lib/yarv2llvm.rb'
end

module YARV2LLVM
class YarvTranslatorToRuby<YarvVisitor
  def initialize(iseq, bind, preload)
    super(iseq, preload)
    @generated_code = Hash.new("")
    @labels = {}
    @expstack = []
    @locals = {}
    @curlabel = ""
    @curlln = ""
  end
  
  def to_ruby
    run
    res = ""
    @labels[:_blk_].each do |lab|
      res = res + @generated_code[lab]
    end
    res = res +  "\n"
    res
  end
  
  def visit_block_start(code, ins, local_vars, ln, info)
    @curlabel = info[1].to_s.gsub(/\+/, '_').to_sym
    lbase = ([nil, nil] + code.header['locals'].reverse)
    lbase.each_with_index do |n, i|
      local_vars[i] = {
        :name => n, 
        :type => RubyType.new(nil, info[3], n),
        :area => nil}
    end
    @locals[code] = local_vars
    @labels[@curlabel] = []
    @labels[@curlabel].push @curlabel
    numarg = code.header['misc'][:arg_size]
    localsiz = code.header['misc'][:local_size]
    initarg = ""
    numarg.times do |i|
      vn = local_vars[i + localsiz - numarg + 1][:name]
      initarg += "#{vn} = para[:args]\n"
    end
    @generated_code[@curlabel] = <<-EOS
   #{initarg}
__state = #{ln.inspect}
while true
  case __state
  when #{ln.inspect}
EOS
  end

  def visit_block_end(code, ins, local_vars, ln, info)
    ret = @expstack.pop
    lln = @labels[@curlabel].last
    @generated_code[lln] = <<-EOS
    #{@generated_code[lln]}
    break #{ret}
  end
end
EOS
  end

  def visit_local_block_start(code, ins, local_vars, ln, info)
    if ln then
      @curlln = (@curlabel.to_s + ln).to_sym
      @labels[@curlabel].push @curlln
      @generated_code[@curlln] = <<-EOS 
__state = #{ln.inspect}
when #{ln.inspect}
EOS
    end
  end

  def visit_local_block_end(code, ins, local_vars, ln, info)
  end

  def visit_default(code, ins, local_vars, ln, info)
  end

  def visit_number(code, ins, local_vars, ln, info)
  end

  def visit_getlocal(code, ins, local_vars, ln, info)
    voff = ins[1]
    if code.header['type'] == :block then
      acode = code
      slev = 0
      while acode.header['type'] == :block
        acode = acode.parent
        slev = slev + 1
      end
      @expstack.push @locals[acode][voff][:name]
    else
      @expstack.push local_vars[voff][:name]
    end
  end
      
  def visit_setlocal(code, ins, local_vars, ln, info)
    voff = ins[1]
    val = @expstack.pop
    if code.header['type'] == :block then
      acode = code
      slev = 0
      while acode.header['type'] == :block
        acode = acode.parent
        slev = slev + 1
      end
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{acode[voff][:name]} = #{val}\n"
    else
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{local_vars[voff][:name]} = #{val}\n"
    end
  end
      
  # getspecial
  # setspecial
      
  def visit_getdynamic(code, ins, local_vars, ln, info)
    slev = ins[2]
    voff = ins[1]
    if slev == 0 then
      @expstack.push local_vars[voff][:name]
    else
      acode = code
      slev.times { acode = acode.parent}
      @expstack.push @locals[acode][voff][:name]
    end
  end
      
  def visit_setdynamic(code, ins, local_vars, ln, info)
    slev = ins[2]
    voff = ins[1]
    val = @expstack.pop
    if slev == 0 then
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{local_vars[voff][:name]} = #{val}\n"
    else
      acode = code
      slev.times { acode = acode.parent}
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{acode[voff][:name]} = #{val}\n"
    end
  end
      
  def visit_getinstancevariable(code, ins, local_vars, ln, info)
  end
      
  def visit_setinstancevariable(code, ins, local_vars, ln, info)
  end
      
  # getclassvariable
  # setclassvariable
      
  def visit_getconstant(code, ins, local_vars, ln, info)
    const = ins[1]
    recv = @expstack.pop
    if recv == "nil" then
      @expstack.push const.to_s
    else
      @expstack.push "#{recv}:#{const.to_s}"
    end
  end
      
  def visit_setconstant(code, ins, local_vars, ln, info)
  end
      
  def visit_getglobal(code, ins, local_vars, ln, info)
  end
      
  def visit_setglobal(code, ins, local_vars, ln, info)
  end
      
  def visit_putnil(code, ins, local_vars, ln, info)
    @expstack.push 'nil'
  end
      
  def visit_putself(code, ins, local_vars, ln, info)
    @expstack.push 'self'
  end
      
  def visit_putobject(code, ins, local_vars, ln, info)
    p1 = ins[1].inspect
    @expstack.push p1
  end
      
  # putspecialobject
      
  def visit_putiseq(code, ins, local_vars, ln, info)
  end
      
  def visit_putstring(code, ins, local_vars, ln, info)
    p1 = ins[1].inspect
    @expstack.push p1
  end
      
  def visit_concatstrings(code, ins, local_vars, ln, info)
    nele = ins[1]
    eles = []
    nele.times do
      eles.push @expstack.pop
    end
    @expstack.push eles.reverse
  end
      
  def visit_tostring(code, ins, local_vars, ln, info)
    v = @expstack.pop
    @expstack.push "#{v}.to_s"
  end
      
  # toregexp
      
  def visit_newarray(code, ins, local_vars, ln, info)
    nele = ins[1]
    inits = []
    nele.times {|n|
      inits.push @expstack.pop
    }
    @expstack.push inits
  end
      
  def visit_duparray(code, ins, local_vars, ln, info)
    srcarr = ins[1]
    @expstack.push srcarr.dup
  end
      
  # expandarray
  # concatarray
  # splatarray
  # checkincludearray
  # newhash
      
  def visit_newrange(code, ins, local_vars, ln, info)
  end
      
  def visit_pop(code, ins, local_vars, ln, info)
    @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{@expstack.pop}\n"
  end
      
  def visit_dup(code, ins, local_vars, ln, info)
    @expstack.push @expstack.last
  end
      
  def visit_dupn(code, ins, local_vars, ln, info)
  end
      
  # swap
  # reput
  # topn
  # setn
  # adjuststack
  
  # defined
      
  def visit_trace(code, ins, local_vars, ln, info)
  end
      
  def visit_defineclass(code, ins, local_vars, ln, info)
  end
      
  def visit_send(code, ins, local_vars, ln, info)
    mname = ins[1]
    nargs = ins[2]
    res = mname

    blk = ""
    blklab = (@curlabel.to_s + "_blk_" + ins[3][1].to_s).to_sym
#    @labels[blklab].each do |lab|
#      blk = blk + @generated_code[lab]
#    end

    args = []
    nargs.times do
      args.push @expstack.pop
    end
    recv = @expstack.pop
    if recv != 'nil' then
      if args.size == 0 then
        @expstack.push "#{recv}.#{mname} #{blk}"
      else
        @expstack.push "#{recv}.#{mname}(#{args.reverse.join(',')}) #{blk}"
      end
    else
      case mname
      when :"`"
        case args[0]
        when Array
          i = 0
          argstr = ""
          arghash = {}
          args[0].each do |e|
            case e
            when /^\"(.*)\"$/
              argstr += $1
            when /^(.*)\.to_s$/
              sym = "gEN#{i}"
              i = i + 1
              argstr += " #{sym} "
              arghash[sym.to_sym] = $1
            end
          end
          
          hashlit = ""
          arghash.map { |vn, val|
            stub = <<-EOS
lambda { |pa|
  @expstack.push [#{val}[0],
    lambda {|b, context|
      context = #{val}[1].call(b, context)
      context
  }]
}
EOS
            hashlit += ":#{vn} => #{val},"
          }
          res = ""
          res += "__lOHash = {#{hashlit}}\n"
          res += "__lOStr = #{argstr.inspect}\n"
          arghash.each do |vn, val|
            res += "if #{val}.is_a?(Symbol) then\n"
            res += "__lOStr.gsub!(' #{vn} ', #{val}.to_s)\n"
            res += "__lOHash.delete(#{vn.inspect})\n"
            res += "end\n"
          end
          @expstack.push [res, "compile_for_macro(__lOStr, __lOHash, para)\n"]
        else
          @expstack.push "compile_for_macro(#{args.reverse.join(',')}, {}, para)"
        end
      else
        if args.size == 0 then
          @expstack.push "#{mname}"
        else
          @expstack.push "#{mname}(#{args.reverse.join(',')})"
        end
      end
    end
  end
      
  # invokesuper
      
  def visit_invokeblock(code, ins, local_vars, ln, info)
    narg = ins[1]
    args = []
    narg.times do |n|
      args.push @expstack.pop
    end
    @expstack.push "yield(#{args.reverse.join(',')})"
  end
      
  def visit_leave(code, ins, local_vars, ln, info)
    ret = @expstack.pop
    if ret.is_a?(Array) then
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\n#{ret[0]}\nbreak (#{ret[1]})"
    else
      @generated_code[@curlln] = "#{@generated_code[@curlln]}\nbreak (#{ret})"
    end
  end
      
  # finish
      
  # throw
      
  def visit_jump(code, ins, local_vars, ln, info)
    lab = ins[1]
    @generated_code[@curlln] = <<-EOS
#{@generated_code[@curlln]}
__state = #{lab.inspect}
next
EOS
  end

  def visit_branchif(code, ins, local_vars, ln, info)
    cond = @expstack.pop
    lab = ins[1]
    @generated_code[@curlln] = <<-EOS
#{@generated_code[@curlln]}
if (#{cond}) then
    __state = #{lab.inspect}
    next
end
EOS
  end

  def visit_branchunless(code, ins, local_vars, ln, info)
    cond = @expstack.pop
    lab = ins[1]
    @generated_code[@curlln] = <<-EOS
#{@generated_code[@curlln]}
if !(#{cond}) then
    __state = #{lab.inspect}
    next
end
EOS
  end

  # getinlinecache
  # onceinlinecache
  # setinlinecache
  # opt_case_dispatch
  # opt_checkenv
  
  def visit_opt_plus(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) + (#{b}))\n"
  end

  def visit_opt_minus(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) - (#{b}))\n"
  end

  def visit_opt_mult(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) * (#{b}))\n"
  end

  def visit_opt_div(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) / (#{b}))\n"
  end

  def visit_opt_mod(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) % (#{b}))\n"
  end

  def visit_opt_eq(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) == (#{b}))\n"
  end

  def visit_opt_neq(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) != (#{b}))\n"
  end

  def visit_opt_lt(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) < (#{b}))\n"
  end

  def visit_opt_le(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) <= (#{b}))\n"
  end

  def visit_opt_gt(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) > (#{b}))\n"
  end

  def visit_opt_ge(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) <= (#{b}))\n"
  end

  def visit_opt_ltlt(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "((#{a}) << (#{b}))\n"
  end

  def visit_opt_aref(code, ins, local_vars, ln, info)
    b = @expstack.pop
    a = @expstack.pop
    @expstack.push "(#{a}[#{b}])"
  end

  # opt_aset
  # opt_length
  # opt_succ
  # opt_not
  # opt_regexpmatch1
  # opt_regexpmatch2
  # opt_call_c_function
  
  # bitblt
  # answer
end
end

if __FILE__ == $0 then
  prog = <<-'EOS'
a = 10
while a > 1 do 
#  p Math.sin(2.0)
  p `#{a} ,a`
  a = a - 1
end
=begin
if a == 1 then
  1
else
  3
end
=end
EOS
  is = RubyVM::InstructionSequence.compile( prog, "foo", 1, 
            {  :peephole_optimization    => true,
               :inline_const_cache       => false,
               :specialized_instruction  => true,}).to_a
  iseq = VMLib::InstSeqTree.new(nil, is)
  print YARV2LLVM::YarvTranslatorToRuby.new(iseq, binding, []).to_ruby
end
