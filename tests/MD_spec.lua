describe("manual-installs", function()
  it("can be required", function()
    require("manual-installs")
  end)



  it("testing configs", function()
    opts = {
                    paths = {
                        download = vim.env.HOME .. "/Downloads2"
                    },
                  github_zip_base_str_pattern = "https://codeload.github.com/%s/zip/refs/heads/%s",
                  wait_seconds = 5,
                  max_retries_for_zip_file = 5,
                  branchs = {'main', 'master'},
                  unzip_wait_time = 1000, -- time to wait for unzip operation
                  -- silent = false,
    }
   MD_test = require("manual-installs").setup(opts)

  end)
end)
--
--
-- local eq = assert.are.equal
-- local manual_installs = require("manual-installs")
--
-- describe("manual-installs", function()
--   local default_opts
--
--   before_each(function()
--     default_opts = {
--       paths = {
--         download = vim.env.HOME .. "/Downloads2"
--       },
--       github_zip_base_str_pattern = "https://codeload.github.com/%s/zip/refs/heads/%s",
--       wait_seconds = 5,
--       max_retries_for_zip_file = 5,
--       branchs = {'main', 'master'},
--       unzip_wait_time = 1000,
--     }
--   end)
--
--   it("should initialize with default configs", function()
--     local MD_test = manual_installs.setup(default_opts)
--
--     -- Test that setup returns something
--     assert.is_not_nil(MD_test)
--
--     -- If your module exposes config, test it
--     -- assert.are.equal(MD_test.config.wait_seconds, 5)
--     -- assert.are.equal(MD_test.config.max_retries_for_zip_file, 5)
--   end)
--
--   it("should handle custom download path", function()
--     local custom_opts = vim.tbl_deep_extend("force", default_opts, {
--       paths = {
--         download = "/tmp/custom_downloads"
--       }
--     })
--
--     local MD_test = manual_installs.setup(custom_opts)
--     assert.is_not_nil(MD_test)
--
--     -- Test that the custom path is used
--     -- assert.are.equal(MD_test.config.paths.download, "/tmp/custom_downloads")
--   end)
--
--   it("should validate required configuration", function()
--     -- Test with missing required config
--     local incomplete_opts = {
--       wait_seconds = 5
--     }
--
--     -- If your setup should throw errors for invalid config:
--     -- assert.has_error(function()
--     --   manual_installs.setup(incomplete_opts)
--     -- end)
--   end)
--
--   it("should use correct branch defaults", function()
--     local MD_test = manual_installs.setup(default_opts)
--
--     -- Test branch configuration
--     -- assert.are.same(MD_test.config.branchs, {'main', 'master'})
--   end)
-- end)
