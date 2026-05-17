require_relative '../test_helper'

# Rack endpoint at /itex (app/metal/itex.rb) — invoked by svg-edit's TeX
# extension. Stateless TeX → MathML converter, no session/web context.
class ItexEndpointTest < ActionDispatch::IntegrationTest
  def test_inline_tex
    post "/itex", params: { tex: "x^2" }
    assert_response :success
    assert_equal "application/xml", response.media_type
    assert_match %r{<math .*display=['"]inline['"]}, response.body
    assert_match %r{<msup>.*<mi>x</mi>.*<mn>2</mn>.*</msup>}m, response.body
  end

  def test_block_tex
    post "/itex", params: { tex: "x^2", display: "block" }
    assert_response :success
    assert_match %r{<math .*display=['"]block['"]}, response.body
  end

  def test_blank_tex_returns_empty_math
    post "/itex", params: { tex: "" }
    assert_response :success
    assert_match %r{<math .*display=['"]inline['"]/>}, response.body
  end

  def test_malformed_tex_returns_merror
    # itex2MML is a C extension that writes parse errors to fd 2 directly,
    # so redirect at the FD level (not $stderr) to keep the test output clean.
    silence_fd2 do
      post "/itex", params: { tex: '\unknowncommand{' }
    end
    assert_response :success
    assert_match %r{<merror>}, response.body
  end

  def test_get_with_query_string
    get "/itex", params: { tex: "a+b" }
    assert_response :success
    assert_match %r{<mi>a</mi>}, response.body
  end

  private

  def silence_fd2
    orig = STDERR.dup
    STDERR.reopen(File::NULL)
    yield
  ensure
    STDERR.reopen(orig)
    orig.close
  end
end
