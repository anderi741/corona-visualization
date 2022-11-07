defmodule Virus_sim.Person do
  @moduledoc """
  Template struct for person
  """

  @doc """
  - location: %Virus_sim.Location Holds the location-struct minus the location_list
  - location_pid: pid() the pid of said location
  - status: :infected | :not_infected | :dead | :recovered
  - containment_measures: nil | :social_distancing | :lockdown
  - symptoms: nil | :none | :mild | :critical when infected, are you showing symptoms or not. If you're not sick yet, is nil. Takes 2-14 incubation days for you to trigger symptoms.
  - incubation_time: If you're infected and has nil symptoms the incubation time is the time until you'll get symptoms. Otherwise if you're infected it's the time until you either die or recover
  - infection_rate: integer() The odds of an infection happening every tick
  - incubation_time_range, {inc_time_low, inc_time_high}: {integer(), integer()} Incubation time (time to start of symptoms) of infected person will be in range inc_time_low to inc_time_high
  - severity_rates, {death_rate, asymptomatic_rate}: {integer(), integer()} death_rate is percentage of infected people who will die without medical attention, asymptomatic_rate is percentage of infected people without symptoms
  - time: integer(), the time step the person is on
  - tick_length, integer(), the length of a tick (in ms) in the simulation
  - important_pids: a map of important pids
  - stats: a map of stats
  """

  defstruct location: nil,
    location_pid: nil,
    status: :not_infected,
    containment_measures: nil,
    symptoms: nil,
    immune_system: Enum.random(1..100),
    incubation_time_range: nil,
    incubation_time: nil,
    infection_rate: 100,
    severity_rates: nil,
    time: 0,
    tick_length: nil,
    important_pids: %{location_supervisor: nil},
    stats: %{infections: 0, infected: false, healed: false}
end
