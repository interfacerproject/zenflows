defmodule ZenflowsTest.Restroom do
use ExUnit.Case, async: true

import Zenflows.Restroom

test "`byte_equal?/2` returns `true` when the two matches" do
	assert byte_equal?("42", "42")
end

test "`byte_equal?/2` returns `false` when the two doesn't match" do
	refute byte_equal?("42", "41")
end
end
