return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "mfussenegger/nvim-dap-python",
    },
    keys = {
      -- Preserved from the original config. NOTE: F1/F2/F10 are often hijacked by macOS; use <leader>d* alternatives.
      {
        "<F5>",
        function()
          require("devenv.dap").continue()
        end,
        desc = "Debug: start/continue",
      },
      {
        "<F10>",
        function()
          require("dap").step_over()
        end,
        desc = "Debug: step over",
      },
      {
        "<F1>",
        function()
          require("dap").step_into()
        end,
        desc = "Debug: step into",
      },
      {
        "<F2>",
        function()
          require("dap").step_out()
        end,
        desc = "Debug: step out",
      },
      {
        "<leader>b",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle breakpoint",
      },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Debug: toggle UI",
      },
      -- Reliable alternatives
      {
        "<leader>dc",
        function()
          require("devenv.dap").continue()
        end,
        desc = "Debug: start/continue",
      },
      {
        "<leader>dn",
        function()
          require("dap").step_over()
        end,
        desc = "Debug: step over (next)",
      },
      {
        "<leader>di",
        function()
          require("dap").step_into()
        end,
        desc = "Debug: step into",
      },
      {
        "<leader>do",
        function()
          require("dap").step_out()
        end,
        desc = "Debug: step out",
      },
      {
        "<leader>dp",
        function()
          require("dap").pause()
        end,
        desc = "Debug: pause",
      },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Condition: "))
        end,
        desc = "Debug: conditional breakpoint",
      },
      {
        "<leader>dC",
        function()
          require("dap").clear_breakpoints()
        end,
        desc = "Debug: clear breakpoints",
      },
      {
        "<leader>dr",
        function()
          require("dap").restart()
        end,
        desc = "Debug: restart",
      },
      {
        "<leader>dx",
        function()
          require("dap").terminate()
        end,
        desc = "Debug: terminate",
      },
      {
        "<leader>dl",
        function()
          require("dap").run_last()
        end,
        desc = "Debug: run last",
      },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "v" },
        desc = "Debug: evaluate",
      },
      {
        "<leader>dE",
        function()
          require("dap").set_exception_breakpoints()
        end,
        desc = "Debug: choose exception breakpoints",
      },
      {
        "<leader>da",
        function()
          require("devenv.dap").attach()
        end,
        desc = "Debug: attach to process",
      },
      {
        "<leader>dt",
        function()
          require("devenv.dap").debug_test()
        end,
        desc = "Debug: test (nearest)",
      },
    },
    config = function()
      require("devenv.dap").setup()
    end,
  },
}
