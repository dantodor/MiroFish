defmodule MiroexWeb.ProjectLive.StepIndicator do
  use MiroexWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center gap-4 mb-8">
      <%= for {step, idx} <- Enum.with_index(["Graph Build", "Env Setup", "Simulation", "Report", "Interaction"]) do %>
        <div class={[
          "flex items-center",
          if(idx + 1 < @current_step,
            do: "text-green-600",
            else: if(idx + 1 == @current_step, do: "text-orange-500 font-bold", else: "text-gray-400")
          )
        ]}>
          <div class={[
            "w-8 h-8 rounded-full flex items-center justify-center mr-2",
            if(idx + 1 <= @current_step, do: "bg-orange-500 text-white", else: "bg-gray-200")
          ]}>
            {idx + 1}
          </div>
          <span class="hidden sm:inline">{step}</span>
        </div>
        <%= if idx < 4 do %>
          <div class={[
            "w-8 h-1",
            if(idx + 1 < @current_step, do: "bg-green-500", else: "bg-gray-200")
          ]}>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
