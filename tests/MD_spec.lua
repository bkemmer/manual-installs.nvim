local manual_installs = require("manual_installs")

describe("manual-downloader", function()
  -- Test that the module can be required
  it("can be required", function()
    assert.is_not_nil(manual_installs)
  end)

  -- Test default configuration
  describe("default configuration", function()
    it("has expected default values", function()
      local config = manual_installs.config
      assert.is_string(config.paths.download)
      assert.is_string(config.paths.path_packages)
      assert.is_string(config.github_zip_base_str_pattern)
      assert.is_number(config.wait_seconds)
      assert.is_number(config.max_retries_for_zip_file)
      assert.is_number(config.unzip_wait_time)
      assert.is_table(config.branchs)
      assert.are.same({'main', 'master'}, config.branchs)
    end)

    it("has correct github zip pattern", function()
      assert.equals("https://codeload.github.com/%s/zip/refs/heads/%s",
                   manual_installs.config.github_zip_base_str_pattern)
    end)
  end)

  -- Test setup function
  describe("setup", function()
    it("accepts empty config", function()
      assert.has_no.errors(function()
        manual_installs.setup({})
      end)
    end)

    it("accepts nil config", function()
      assert.has_no.errors(function()
        manual_installs.setup()
      end)
    end)

    it("merges custom config with defaults", function()
      local custom_config = {
        wait_seconds = 10,
        paths = {
          download = "/tmp/test-downloads"
        }
      }

      manual_installs.setup(custom_config)

      assert.equals(10, manual_installs.config.wait_seconds)
      assert.equals("/tmp/test-downloads", manual_installs.config.paths.download)
      -- Should preserve other defaults
      assert.equals(5, manual_installs.config.max_retries_for_zip_file)
    end)

    it("validates config types", function()
      assert.has_error(function()
        manual_installs.setup("invalid")
      end)

      assert.has_error(function()
        manual_installs.setup({
          paths = "invalid"
        })
      end)
    end)
  end)

  -- Test URL generation
  describe("get_branch_url", function()
    it("generates correct URL for main branch", function()
      local url = manual_installs.get_branch_url("user/repo", "main")
      assert.equals("https://codeload.github.com/user/repo/zip/refs/heads/main", url)
    end)

    it("generates correct URL for custom branch", function()
      local url = manual_installs.get_branch_url("user/repo", "develop")
      assert.equals("https://codeload.github.com/user/repo/zip/refs/heads/develop", url)
    end)

    it("handles special characters in repo name", function()
      local url = manual_installs.get_branch_url("user/repo-with-dashes", "main")
      assert.equals("https://codeload.github.com/user/repo-with-dashes/zip/refs/heads/main", url)
    end)
  end)

  -- Test repository name extraction
  describe("get_repo_name", function()
    it("extracts repo name from author/repo format", function()
      local repo_name = manual_installs.get_repo_name("user/my-repo")
      assert.equals("my-repo", repo_name)
    end)

    it("handles nested paths", function()
      local repo_name = manual_installs.get_repo_name("user/nested/repo")
      assert.equals("repo", repo_name)
    end)

    it("handles single name", function()
      local repo_name = manual_installs.get_repo_name("repo")
      assert.equals("repo", repo_name)
    end)
  end)

  -- Test zip filename generation
  describe("get_zip_filename", function()
    it("generates correct filename", function()
      local filename = manual_installs.get_zip_filename("my-repo", "main")
      assert.equals("my-repo-main.zip", filename)
    end)

    it("handles different branches", function()
      local filename = manual_installs.get_zip_filename("my-repo", "develop")
      assert.equals("my-repo-develop.zip", filename)
    end)
  end)

  -- Test path utilities
  describe("get_full_path_with_downloads_folder", function()
    it("joins paths correctly", function()
      -- Setup a known download path
      manual_installs.setup({
        paths = {
          download = "/tmp/downloads"
        }
      })

      local full_path = manual_installs.get_full_path_with_downloads_folder("test.zip")
      assert.equals("/tmp/downloads/test.zip", full_path)
    end)
  end)

  -- Test branch removal utility
  describe("remove_branch_from_string", function()
    it("removes main branch from string", function()
      local result = manual_installs.remove_branch_from_string("repo-name-main")
      assert.equals("repo-name", result)
    end)

    it("removes master branch from string", function()
      local result = manual_installs.remove_branch_from_string("repo-name-master")
      assert.equals("repo-name", result)
    end)

    it("preserves non-branch suffixes", function()
      local result = manual_installs.remove_branch_from_string("repo-name-v1.0")
      assert.equals("repo-name-v1.0", result)
    end)

    it("handles multiple dashes", function()
      local result = manual_installs.remove_branch_from_string("my-repo-name-main")
      assert.equals("my-repo-name", result)
    end)

    it("handles no branch suffix", function()
      local result = manual_installs.remove_branch_from_string("repo-name")
      assert.equals("repo-name", result)
    end)
  end)

  -- Test path stem utility
  describe("stem_path", function()
    it("removes file extension", function()
      local stem = manual_installs.stem_path("/path/to/file.zip")
      assert.equals("file", stem)
    end)

    it("handles multiple dots", function()
      local stem = manual_installs.stem_path("/path/to/file.tar.gz")
      assert.equals("file", stem)
    end)

    it("handles no extension", function()
      local stem = manual_installs.stem_path("/path/to/file")
      assert.equals("file", stem)
    end)
  end)

  -- Test file existence checking
  describe("check_if_path_already_exists", function()
    it("returns nil for non-existent path", function()
      local exists = manual_installs.check_if_path_already_exists("/non/existent/path")
      assert.is_nil(exists)
    end)

    it("returns true for existing path", function()
      -- Create a temporary file for testing
      local temp_file = "/tmp/test_file_" .. os.time()
      local file = io.open(temp_file, "w")
      file:write("test")
      file:close()

      local exists = manual_installs.check_if_path_already_exists(temp_file)
      assert.is_true(exists)

      -- Clean up
      os.remove(temp_file)
    end)
  end)

  -- Test URL validation (mocked)
  describe("test_url_exists", function()
    it("handles valid response", function()
      -- Mock vim.fn.system to return successful HTTP response
      local original_system = vim.fn.system
      vim.fn.system = function(cmd)
        return "HTTP/1.1 200 OK\nContent-Type: application/zip"
      end

      local exists = manual_installs.test_url_exists("https://example.com/test.zip")
      assert.is_true(exists)

      -- Restore original function
      vim.fn.system = original_system
    end)

    it("handles invalid response", function()
      -- Mock vim.fn.system to return 404 response
      local original_system = vim.fn.system
      vim.fn.system = function(cmd)
        return "HTTP/1.1 404 Not Found"
      end

      local exists = manual_installs.test_url_exists("https://example.com/nonexistent.zip")
      assert.is_nil(exists)

      -- Restore original function
      vim.fn.system = original_system
    end)
  end)

  -- Test get_valid_url with mocked URL testing
  describe("get_valid_url", function()
    local original_test_url_exists

    before_each(function()
      original_test_url_exists = manual_installs.test_url_exists
    end)

    after_each(function()
      manual_installs.test_url_exists = original_test_url_exists
    end)

    it("returns custom branch URL when it exists", function()
      manual_installs.test_url_exists = function(url)
        return url:match("custom%-branch") and true or nil
      end

      local url, branch = manual_installs.get_valid_url("user/repo", "custom-branch")
      assert.is_string(url)
      assert.equals("custom-branch", branch)
    end)

    it("returns nil when custom branch doesn't exist", function()
      manual_installs.test_url_exists = function(url)
        return nil
      end

      local url, branch = manual_installs.get_valid_url("user/repo", "nonexistent")
      assert.is_nil(url)
      assert.is_nil(branch)
    end)

    it("tries default branches when no custom branch specified", function()
      manual_installs.test_url_exists = function(url)
        return url:match("main") and true or nil
      end

      local url, branch = manual_installs.get_valid_url("user/repo", nil)
      assert.is_string(url)
      assert.equals("main", branch)
    end)

    it("returns nil when no branches exist", function()
      manual_installs.test_url_exists = function(url)
        return nil
      end

      local url, branch = manual_installs.get_valid_url("user/repo", nil)
      assert.is_nil(url)
      assert.is_nil(branch)
    end)
  end)

  -- Integration test for the main downloader function
  describe("downloader", function()
    it("validates input parameters", function()
      assert.has_error(function()
        manual_installs.downloader("user/repo", 123) -- invalid output_dir type
      end)

      assert.has_error(function()
        manual_installs.downloader("user/repo", nil, 123) -- invalid custom_branch type
      end)
    end)

    it("handles non-existent repository gracefully", function()
      -- Mock test_url_exists to return nil (repo doesn't exist)
      local original_test_url_exists = manual_installs.test_url_exists
      manual_installs.test_url_exists = function(url)
        return nil
      end

      -- Should not error, just return without doing anything
      assert.has_no.errors(function()
        manual_installs.downloader("user/nonexistent-repo")
      end)

      -- Restore original function
      manual_installs.test_url_exists = original_test_url_exists
    end)
  end)
end)
