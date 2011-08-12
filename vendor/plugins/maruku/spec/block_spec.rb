#!/usr/bin/env ruby -w
# encoding: UTF-8
Encoding.default_external=('UTF-8') if ''.respond_to?(:force_encoding)
require File.dirname(__FILE__) + "/spec_helper"

METHODS = [:to_html, :to_latex, :to_md, :to_s]

describe "A Maruku document" do
  before(:all) do
    @old_stderr = $stderr
    $stderr = StringIO.new
  end

  after(:all) do
    $stderr = @old_stderr
  end

  Dir[File.dirname(__FILE__) + "/block_docs/**/*.md"].each do |md|
    describe " for the #{md} file" do
      input = File.read(md).split(/\n\*{3}[^*\n]+\*{3}\n/m)
      input = ["Write a comment here", "{}", input.first] if input.size == 1
      comment = input.shift
      params = eval(input.shift)
      markdown = input.shift
      ast = input.shift

      before(:each) do
        pending if md =~ Regexp.new("^" + Regexp.quote(File.dirname(__FILE__) + "/block_docs/red_tests"))

        $already_warned_itex2mml = false
        @doc = Maruku.new(markdown, params)
        @expected = METHODS.zip(input).inject({}) {|h, (k, v)| h[k] = v ? v.strip : '' ; h}
      end

      it "should read in the output of #inspect as the same document" do
        Maruku.new.instance_eval(@doc.inspect).should == @doc
      end

      it "should read in the given AST as the same document" do
        Maruku.new.instance_eval(ast).should == @doc
      end

      METHODS.each do |m|
        it "should have the expected ##{m} output" do
          res = @doc.send(m).strip
          pending "install itex2mml" if m == :to_html && $already_warned_itex2mml
          res.should == @expected[m]
        end
      end
    end
  end
end
