defmodule Virus_sim.Location_counter do
  @moduledoc """
  Template struct for location counters
  """
  @doc """
  - name: String, The name of the location.
  - i: integer() The amount of infected people at the location
  - n: integer() The amount of not_infected people at the location
  - d: integer() The amount of dead people at the location
  - r: integer() The amount of recovered people at the location
  - max_cap: the maximum amount of people that can be at the location at the same time. If nil the max cap is infinite(in theory)
  - type: The type of the location
  """
  defstruct name: "",
    i: 0,
    n: 0,
    d: 0,
    r: 0,
    max_cap: nil,
    type: nil
end
