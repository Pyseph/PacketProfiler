local Vector2 = import("./Vector2")

local function extractValues(v)
	return { v.X, v.Y }
end


describe("types.Vector2", function()
	it("should have an empty constructor", function()
		local v = Vector2.new()

		assert.not_nil(v)
		assert.are.same({0, 0}, extractValues(v))
	end)

	it("should have a constructor with two parameters", function()
		local v = Vector2.new(1, 200)

		assert.not_nil(v)
		assert.are.same({1, 200}, extractValues(v))
	end)

	it("should throw when bad params are passed to the constructor", function()
		assert.has.errors(function()
			Vector2.new(1, "test")
		end)

		assert.has.errors(function()
			Vector2.new("test", 10)
		end)
	end)

	it("should add another Vector2", function()
		local vectorA = Vector2.new(1, 200)
		local vectorB = Vector2.new(100, 500)
		local v = vectorA + vectorB

		assert.not_nil(v)
		assert.are.same({101, 700}, extractValues(v))
	end)

	it("should subtract another Vector2", function()
		local vectorA = Vector2.new(1, 200)
		local vectorB = Vector2.new(100, 500)
		local v = vectorA - vectorB

		assert.not_nil(v)
		assert.are.same({-99, -300}, extractValues(v))
	end)

	it("should equal another Vector2 with the same x and y", function()
		local vectorA = Vector2.new(1, 200)
		local vectorB = Vector2.new(1, 200)

		assert.equals(vectorA, vectorB)
	end)

	it("should not equal another UDim with different scale and offset", function()
		local vectorA = Vector2.new(1, 200)

		local vectorB1 = Vector2.new(10, 200)
		local vectorB2 = Vector2.new(1, 300)
		local vectorB3 = Vector2.new(5, 10)

		assert.not_equals(vectorA, vectorB1)
		assert.not_equals(vectorA, vectorB2)
		assert.not_equals(vectorA, vectorB3)
	end)
end)
