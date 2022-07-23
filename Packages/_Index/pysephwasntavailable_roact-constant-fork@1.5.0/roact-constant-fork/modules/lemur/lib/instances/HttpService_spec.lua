local HttpService = import("./HttpService")

describe("instances.HttpService", function()
	it("should instantiate", function()
		local instance = HttpService:new()

		assert.not_nil(instance)
	end)

	it("should json encode properly", function()
		local instance = HttpService:new()

		assert.equal(instance:JSONEncode({ 1, true }), "[1,true]")
	end)

	it("should json decode properly", function()
		local instance = HttpService:new()

		assert.are.same(instance:JSONDecode("[1,true]"), { 1, true })
	end)

	describe("GenerateGUID", function()
		it("should omit curly braces when wrapInCurlyBraces is false", function()
			local instance = HttpService:new()
			local guid = instance:GenerateGUID(false)

			assert.equal(guid:find("{"), nil)
			assert.equal(guid:find("}"), nil)
		end)

		it("should include curly braces when wrapInCurlyBraces is nil or true", function()
			local instance = HttpService:new()
			local guid = instance:GenerateGUID(true)

			assert.equal(guid:find("{.+}"), 1)

			guid = instance:GenerateGUID()

			assert.equal(guid:find("{.+}"), 1)
		end)

		it("should throw when given invalid arg types", function()
			local instance = HttpService:new()

			assert.has_error(function() instance:GenerateGUID(newproxy()) end)
			assert.has_error(function() instance:GenerateGUID({}) end)
			assert.has_error(function() instance:GenerateGUID(function() end) end)
		end)
	end)
end)