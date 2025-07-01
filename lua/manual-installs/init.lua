local MD = {}
local H = {}

-- Utils from MiniDeps
H.error = function(msg) error('(manual_downloader) ' .. msg, 0) end

H.check_type = function(name, val, ref, allow_nil)
  if type(val) == ref or (ref == 'callable' and vim.is_callable(val)) or (allow_nil and val == nil) then return end
  H.error(string.format('`%s` should be %s, not %s', name, ref, type(val)))
end

H.setup_config = function(config)
  H.check_type('config', config, 'table', true)
  config = vim.tbl_deep_extend('force', vim.deepcopy(MD.config), config or {})

  H.check_type('paths', config.paths, 'table')
  H.check_type('path.download', config.path.download, 'string')
  H.check_type('github_zip_base_str_pattern', config.github_zip_base_str_pattern, 'string')
  H.check_type('wait_seconds', config.wait_seconds, 'integer')
  H.check_type('max_retries_for_zip_file', config.max_retries_for_zip_file, 'integer')
  -- H.check_type('silent', config.silent, 'boolean')

  return config
end

-- -- print a table
-- H.tprint = function(t_, notify)
--   for i, e in ipairs(t_) do
--     if notify ~= nil then
--       vim.notify(i .. ": " .. e)
--     else
--       print(i .. ": " .. e)
--     end
--   end
-- end
--
-- end helpers

MD.config = {
  paths = {
    download = vim.env.HOME .. "/Downloads"
  },
  github_zip_base_str_pattern = "https://codeload.github.com/%s/zip/refs/heads/%s",
  wait_seconds = 5,
  max_retries_for_zip_file = 5,
  branchs = {'main', 'master'},
  unzip_wait_time = 1000, -- time to wait for unzip operation
  -- silent = false,
}


MD.setup = function(config)
  MD.config = H.setup_config(config)
end

---@param author_repo_name string The repository name in the pattern: bkemmer/dot-files
---@param branch string The branch name
---@return string success Return the url with the author/repository_name/branch
MD.get_branch_url = function(author_repo_name, branch)
  return string.format(MD.config.github_zip_base_str_pattern, author_repo_name, branch)
end

---@param url string The URL
---@return boolean|nil
MD.test_url_exists = function(url)
  local curl_cmd = {
    'curl', '--head', '-s', url
  }
  local grep_for_str = 'HTTP.* 200'
  local r_ = vim.fn.system(curl_cmd):find(grep_for_str)
  if r_ ~= nil and r_ > 0 then
    return true
  end
end

---@return string|nil ,string|nil
MD.get_valid_url = function(author_repo_name, custom_branch)

  local function test_url(author_repo_name, branch)
    local url = MD.get_branch_url(author_repo_name, branch)
    local exists = MD.test_url_exists(url)
    if exists then return url, branch
      else return nil, nil end
  end

  if custom_branch ~= nil then
    return test_url(author_repo_name, custom_branch)
  else
    local branchs = MD.config.branchs
    for i=1, #branchs do
      local url, branch = test_url(author_repo_name, branchs[i])
      if url ~= nil then return url, branch end
    end
  end
end

MD.download_using_external_program = function(url)
  local download_program = 'xdg-open'
  if vim.fn.has('macunix') == 1 then download_program = 'open' end
  vim.fn.system({
    download_program, url
  })
end

MD.get_full_path_with_downloads_folder = function(filename)
  return vim.fs.joinpath(MD.config.paths.download, filename)
end

---@param filename string Filename to wait under download folder
---@param callback function Callback function to call with (success: boolean, file_path: string)
MD.wait_for_file = function(filename, callback)
  local full_path = MD.get_full_path_with_downloads_folder(filename)
  local i = 0

  local function check_file()
    if vim.loop.fs_stat(full_path) then
      vim.notify("File found: " .. full_path)
      callback(true, full_path)
      return
    end

    if i >= MD.config.max_retries_for_zip_file then
      vim.notify("Max retries reached. File not found: " .. full_path, vim.log.levels.ERROR)
      callback(false, full_path)
      return
    end

    vim.notify(i .. ": File not present in: " .. full_path .. " waiting " .. MD.config.wait_seconds .. "s")
    i = i + 1
    vim.defer_fn(check_file, MD.config.wait_seconds * 1000)
  end

  check_file()
end

---@param full_zip_path string Full path to zip file
---@param output_dir string Output folder to extract the zip file
---@return nil
MD.unzip_file = function(full_zip_path, output_dir)
  local handle
  handle = vim.loop.spawn("unzip", {
    args = { full_zip_path, "-d", output_dir },
    stdio = {nil, nil, nil}
  }, function(code, signal)
    if code ~= 0 then
      vim.notify("Unzip finished with exit code: " .. code, vim.log.levels.ERROR)
    end
    handle:close()
  end)
end

MD.get_repo_name = function(author_repo_name)
  local parts = vim.split(author_repo_name, "/", { plain = true })
  return parts[#parts]
end

MD.get_zip_filename = function(repo_name, branch)
  return string.format('%s-%s.zip', repo_name, branch)
end

---@return boolean|nil success Returns true if file exists and nil otherwise
MD.check_if_path_already_exists = function(full_filename)
  if vim.loop.fs_stat(full_filename) ~= nil then return true end
end

MD.ask_remove_file = function(full_filepath)
  local choice = vim.fn.confirm(
    string.format("Remove file '%s'?", full_filepath),
    "&yes\n&no",
    2  -- default to "no"
  )
  if choice == 1 then
    -- User confirmed, remove the file
    local success, err = os.remove(full_filepath)
    if success then
      vim.notify(string.format("File '%s' removed successfully", full_filepath))
    else
      vim.notify(string.format("Error removing file: %s", err))
    end
  end
end

---@param origin string Full path of unziped folder usually with the posfix -<branch_name>
MD.rename_folder = function(origin)
  local parts = vim.split(origin, "-", { plain = true })
  local last_part = parts[#parts]
  for _, branch in ipairs(MD.config.branchs) do
    if branch == last_part then
      local destination = {}
      table.move(parts, 1, #parts - 1, 1, destination) -- Removing the posfix
      local destination_str = table.concat(destination, '-') -- returning any previous -
      vim.notify("Renaming " .. origin .. " to " .. destination_str)
      local success, err = vim.loop.fs_rename(origin, destination_str)
      if not success then
        vim.notify("Failure to rename the folder with err: " .. err, vim.log.levels.ERROR)
      end
      return
    end
  end
end

---@return string path folder without file extention
MD.stem_path = function(path)
  local parts = vim.split(path, '/', { plain = true })
  local last_part = parts[#parts]
  return vim.split(last_part, '.', { plain = true })[1]
end

---@param author_repo_name string The repository name in the pattern: bkemmer/dot-files
---@param output_dir string Destination folder to be downloaded
---@param custom_branch string|nil Specific branch to be used
MD.downloader = function(author_repo_name, output_dir, custom_branch)
  H.check_type('output_dir', output_dir, 'string', false)
  H.check_type('custom_branch', custom_branch, 'string', true)

  -- check if this branch hierarchy exists
  local repo_name = MD.get_repo_name(author_repo_name)
  local url, branch  = MD.get_valid_url(author_repo_name, custom_branch)

  if url ~= nil then
    print(url, branch)

    local zip_filename = MD.get_zip_filename(repo_name, branch)
    local full_filepath = MD.get_full_path_with_downloads_folder(zip_filename)

    local destination_folder = output_dir .. '/' .. MD.stem_path(full_filepath)
    if MD.check_if_path_already_exists(destination_folder) then
      vim.notify("Folder " .. destination_folder .. " already exists.", vim.log.levels.ERROR)
      return
    end

    -- check if zip file already exists
    if MD.check_if_path_already_exists(full_filepath) then
      MD.ask_remove_file(full_filepath)
    end

    MD.download_using_external_program(url)

    MD.wait_for_file(zip_filename, function(success, full_filepath)
      if success then
        vim.notify("File ready at: " .. full_filepath)
        vim.notify("Unzipping file: " .. full_filepath .. " to " .. output_dir)
        MD.unzip_file(full_filepath, output_dir)
        vim.wait(MD.config.unzip_wait_time) -- wait some time to the unzip operation
        MD.rename_folder(destination_folder)
      else
        vim.notify("File not found: " .. full_filepath)
      end
    end)

  end

end

-- tests
-- MD.downloader("bkemmer/dot-files", vim.env.HOME .. "/projects/tmp")
-- MD.downloader("Olivine-Labs/lua-style-guide")
-- local full_path = MD.wait_for_file('obs2.png')

-- local full_path = MD.wait_for_file("enel.zip")
-- MD.unzip_file(full_path, MD.config.paths.download)
return MD
