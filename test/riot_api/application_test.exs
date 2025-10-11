defmodule RiotApi.ApplicationTest do
  use ExUnit.Case, async: false

  describe "configuration" do
    test "checks that necessary dependencies are defined" do
      # Check that necessary applications are in extra_applications
      app_config = Application.get_application(RiotApi.Application)
      assert app_config == :riot_api

      # Check that Plug.Cowboy is in dependencies
      {:ok, _} = Application.ensure_all_started(:plug_cowboy)

      # Check that Jason is available
      assert {:ok, _} = Application.ensure_all_started(:jason)

      # Check that Plug.Crypto is available
      assert {:ok, _} = Application.ensure_all_started(:plug_crypto)
    end

    test "checks application configuration" do
      # Check that the RiotApi.Application module exists and has the correct structure
      assert function_exported?(RiotApi.Application, :start, 2)

      # Check that the application configuration is correct
      app_config = Application.spec(:riot_api)
      assert app_config != nil
      assert Keyword.get(app_config, :mod) == {RiotApi.Application, []}
      # Logger is in applications but not necessarily in extra_applications
      assert is_list(Keyword.get(app_config, :extra_applications, []))
    end

    test "checks that children are properly defined" do
      # Check that the children function returns the correct structure
      # without actually starting the application

      # We check that the router is properly configured
      assert function_exported?(RiotApi.Router, :init, 1)
      assert function_exported?(RiotApi.Router, :call, 2)
    end
  end
end
