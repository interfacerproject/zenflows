defmodule ZenflowsTest.Restroom do
use ExUnit.Case, async: true

import Zenflows.Restroom

test "`passgen/1` and `passverify?/2` works together correctly" do
    pass = "hunter2"
    notpass = "hunter"
    hash = passgen(pass)
    assert passverify?(pass, hash)
    refute passverify?(notpass, hash)
end
end
