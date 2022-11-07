defmodule Virus_sim do
  @moduledoc """
  Main module of the prototype
  """

  @doc """
  Initializes the simulation 
  ## Parameters:
  - no_people: integer() The amount of people in the simulation
  - infection_rate: integer() The probability of a person transmitting the disease to another person every second, must be between 1-100
  - incubation_time_range, {inc_time_low, inc_time_high}: {integer(), integer()} Incubation time (time to start of symptoms) of infected person will be in range inc_time_low to inc_time_high
  - severity_rates, {death_rate, asymptomatic_rate}: {integer(), integer()} death_rate is percentage of infected people who will die without medical attention, asymptomatic_rate is percentage of infected people without symptoms
  - icb, integer() amount of intensive care beds per 100 000 people
  """
  def init(no_people, infection_rate, incubation_time_range, severity_rates, icb) do
    
    person_supervisor_pid = spawn_link(fn -> Person_supervisor.loop([], []) end)

    send_pid_to_frontend(:virus_sim, self())
    send_pid_to_frontend(:person_supervisor, person_supervisor_pid)
    
    locations = spawn_generic_locations(round(no_people/1.5)) 
    
    # Creates a Home location and a counter for it 
    # This location will not hold a list of people
    home_counter = %Virus_sim.Location_counter{name: "Home"}
    home_counter_pid = spawn_link(fn -> Location_counter.loop(home_counter) end)
    home = %Virus_sim.Location{name: "Home", counter: home_counter_pid, time_range: {1, 16}}

    # Creates a Graveyard location and a counter for it
    # This location will not hold a list of people
    graveyard_counter = %Virus_sim.Location_counter{name: "Graveyard"}
    graveyard_counter_pid = spawn_link(fn -> Location_counter.loop(graveyard_counter) end)

    # Creates a Hospital location and a counter for it
    # This location will not hold a list of people
    hospital_counter = %Virus_sim.Location_counter{name: "Hospital", max_cap: round(no_people/100000*icb)}
    hospital_counter_pid = spawn_link(fn -> Location_counter.loop(hospital_counter) end)
   
    # Creates a supervisor which will hold all locations that has a people list
    location_supervisor_pid = spawn_link(fn -> Location_supervisor.init(locations) end)
    important_pids = %{location_supervisor: location_supervisor_pid, home_counter: home_counter_pid, graveyard_counter: graveyard_counter_pid, hospital_counter: hospital_counter_pid, person_supervisor: person_supervisor_pid}

    tick_length = decide_tick_length(no_people)
    # result will obtain a list of counter pids for all locations + the last element is the remaning people that will be spawned in Home
    result = spawn_people_in_locations(
      locations,
      no_people,
      infection_rate,
      incubation_time_range,
      tick_length,
      severity_rates,
      important_pids
    )

    # Pops the last element (aka remaining_people)
    {remaining_people, counters} = List.pop_at(result, Enum.count(result) - 1)

    # Spawns the remaining people in Home
    spawn_people(
      home,
      nil,
      remaining_people,
      infection_rate,
      incubation_time_range,
      tick_length,
      severity_rates,
      important_pids,
      false
    )

    counters = [hospital_counter_pid | [graveyard_counter_pid | [home_counter_pid | counters]]]

    Process.sleep(100)
    main_loop(counters, person_supervisor_pid, tick_length, 0)
  end
  
  @doc """
  Spawns a number of generically named locations.
  A location will be of type :work, :store, :restaurant, :transport, :cinema, :park and :gym. The calculations are based on the ratio 50 | 10 | 1 | 10 | 20 | 4 | 5
  ##Parameters:
  - no_people: integer() the number of people we want to put in the locations
  ##Returns: 
  [{struct, pid}..]
  returns a list of tuples with
  - struct: %Virus_sim.Location location struct
  - pid: pid() pid of a location
  for each created location.
  """
  def spawn_generic_locations(no_people) do
    spawn_generic_locations_aux(no_people, [], 0)
  end

  defp spawn_generic_locations_aux(no_people, acc, no_locations) do
    cond do
      no_people < 1 ->
	acc
      rem(no_locations, 2) == 0 ->
	location = spawn_named_location(:work, no_locations, 100, {4, 10}, 0.8)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 50, acc, no_locations + 1)
      rem(no_locations, 10) == 1 ->
	location = spawn_named_location(:store, no_locations, 200, {1, 2}, 0.3)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 100, acc, no_locations + 1)
      rem(no_locations, 10) == 5 ->
	location = spawn_named_location(:restaurant, no_locations, 100, {1, 3}, 0.4)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 50, acc, no_locations + 1)
      rem(no_locations, 10) == 3 or rem(no_locations, 10) == 7 ->
	location = spawn_named_location(:transport, no_locations, 50, {1, 2}, 0.6)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 25, acc, no_locations + 1)
      rem(div(no_locations, 10), 2) == 0 ->
	location = spawn_named_location(:cinema, no_locations, 200, {2, 4}, 0.5)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 100, acc, no_locations + 1)
      rem(no_locations, 99) == 0 ->
	location = spawn_named_location(:park, no_locations, 1000, {1, 8}, 0.1)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 500, acc, no_locations + 1)
      true ->
	location = spawn_named_location(:gym, no_locations, 100, {1, 2}, 1)
	acc = [location | acc]
	spawn_generic_locations_aux(no_people - 50, acc, no_locations + 1)
    end
  end

  @doc """
  Spawns a location with a specific type.
  The name of the location is (type <> no_locations).
  The location will get a maximum capacity of a random 
  value beween  (max_cap - (max_cap/5)) to (max_cap + (max_cap/5)).
  ## Parameters:
  - type: atom() the type of location we want to spawn
  - no_locations: integer() the amount of current locations
  - max_cap: integer() the maximum capacity of the location
  - range: {integer(), integer()} the range of time a person spends at the loaction
  - rate: float() infection_rate the location whould have
  ## Returns:
  - {struct, pid}: 
  - struct: %Virus_sim.location{} The struct of the location
  - pid: pid() The pid of the location
  """
  
  def spawn_named_location(type, no_locations, max_cap, range, rate) do
    name = "#{Atom.to_string(type)}#{no_locations}"
    fifth = div(max_cap, 5)
    max_cap = (:rand.uniform(fifth*2) + (max_cap - fifth)) # om max cap == 100 så ska den slumpa mellan 80 och 120
    counter = %Virus_sim.Location_counter{name: name, max_cap: max_cap, type: type} 
    counter_pid = spawn_link(fn -> Location_counter.loop(counter) end)
    struct = %Virus_sim.Location{name: name, counter: counter_pid, type: type, time_range: range, infection_rate: rate}
    pid = spawn_link(fn -> Location_logic.loop(struct) end)
    {struct, pid}
  end
  
  @doc """
  Spawns a number of people in a location where one is infected
  ## Parameters:
  - location: %Virus_sim.Location struct of the location to spawn people in
  - location_pid: the pid() of said location
  - no_people: integer() amount of people to spawn
  - infection_rate: integer() percentage 0-100 of how likely to infect other people every tick
  - incubation_time_range, {inc_time_low, inc_time_high}: {integer(), integer()} Incubation time (time to start of symptoms) of infected person will be in range inc_time_low to inc_time_high
  - tick_length: ingeteger(), how many ms a tick is going to be
  - severity_rates, {death_rate, asymptomatic_rate}: {integer(), integer()} death_rate is percentage of infected people who will die without medical attention, asymptomatic_rate is percentage of infected people without symptoms
  - important_pids: %{pid()} a map of important pids
  - spawn_infected: boolean() if we should spawn an infected person 
  ## Restrictions:
  - no_people has to be greater than 0
  """

  
  def spawn_people(location, location_pid, 1, infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids, spawn_infected) do
    if spawn_infected do
      infected_person = %Virus_sim.Person{
        location: location,
	location_pid: location_pid,
        status: :infected,
	immune_system: :rand.uniform(100),
	incubation_time_range: {inc_time_low, inc_time_high},
	incubation_time: (Enum.random(inc_time_low..inc_time_high)) * 24, #in days
	tick_length: tick_length,
        infection_rate: infection_rate,
	severity_rates: severity_rates,
        important_pids: important_pids,
	stats: %{infections: 0, infected: true}
      }
      pid = spawn_link(fn -> Person_logic.loop(infected_person) end)
      if location_pid != nil do
	send location_pid, {:new_person, pid}
      end
      send location.counter, {:move_in, :infected}
      send important_pids.person_supervisor, {:insert_pid, pid}
    else
      person = %Virus_sim.Person{
	location: location,
	location_pid: location_pid,
	immune_system: :rand.uniform(100),
	incubation_time_range: {inc_time_low, inc_time_high},
	tick_length: tick_length,
	infection_rate: infection_rate,
	severity_rates: severity_rates,
	important_pids: important_pids
      }
      pid = spawn_link(fn -> Person_logic.loop(person) end)
      if location_pid != nil do
	send location_pid, {:new_person, pid}
      end
      send location.counter, {:move_in, :not_infected}
      send important_pids.person_supervisor, {:insert_pid, pid}
      :ok
    end
  end
  
  def spawn_people(location, location_pid, no_people, infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids, spawn_infected) do
    if no_people < 0 do
      :ok
    else
      person = %Virus_sim.Person{
	location: location,
	location_pid: location_pid,
	immune_system: :rand.uniform(100),
	incubation_time_range: {inc_time_low, inc_time_high},
	tick_length: tick_length,
	infection_rate: infection_rate,
	severity_rates: severity_rates,
	important_pids: important_pids
      }

      pid = spawn_link(fn -> Person_logic.loop(person) end)
      if location_pid != nil do
	send location_pid, {:new_person, pid}
      end
      send location.counter, {:move_in, :not_infected}
      send important_pids.person_supervisor, {:insert_pid, pid}
      
      spawn_people(location, location_pid, no_people - 1, infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids, spawn_infected)
    end
  end

  @doc """
  Recursive function that spawns half the amount of the maximum capacity of the location of people in each location and spawns an infected at the last location
  ## Parameters:
  - [head | locations]: head is the first location, locations is the rest of the locations
  - [only]: if there is only one location left
  - remaining_people: the amount of remaining people that should be spawned among the remaining locations
  - infection_rate: infection rate
  - incubation_time_range, {inc_time_low, inc_time_high}: {integer(), integer()} Incubation time (time to start of symptoms) of infected person will be in range inc_time_low to inc_time_high
  - tick_length: ingeteger(), how many ms a tick is going to be
  - severity_rates, {death_rate, asymptomatic_rate}: {integer(), integer()} death_rate is percentage of infected people who will die without medical attention, asymptomatic_rate is percentage of infected people without symptoms
  - important_pids: important pids
  ## Returns:
  - A list of all the location_counters plus the last element that is the amount of remaining people
  """
  
  def spawn_people_in_locations([only], remaining_people, infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids) do
    {location, location_pid} = only
    send location.counter, {:get_cap, self()}
    cap = receive do
      {:return_cap, cap} ->
	cap
    end
    spawn_people(
      location,
      location_pid,
      div(cap, 2),
      infection_rate,
      {inc_time_low, inc_time_high},
      tick_length,
      severity_rates,
      important_pids,
      true
    )
    [location.counter, remaining_people - div(cap, 2)]
  end
  
  
  def spawn_people_in_locations([head | locations], remaining_people, infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids) do
    {location, location_pid} = head
    send location.counter, {:get_cap, self()}
    cap = receive do
      {:return_cap, cap} ->
	cap
    end
    spawn_people(
      location,
      location_pid,
      div(cap, 2),
      infection_rate,
      {inc_time_low, inc_time_high},
      tick_length,
      severity_rates,
      important_pids,
      false
    )
    [location.counter | spawn_people_in_locations(locations, remaining_people - div(cap, 2), infection_rate, {inc_time_low, inc_time_high}, tick_length, severity_rates, important_pids)]
  end
  
  @doc """
  Loop that prints and writes to file all the information from the locations
  ## Parameters:
  - counters: list() list of all the counter pids
  - person_supervisor: pid of the person supervisor
  - tick_length: integer(), the length of a tick in ms
  - counter: int() counts loop iterations
  """
  def main_loop(counters, person_supervisor, tick_length, counter) do
    
    location_info_list = Enum.map(counters, fn counter_pid ->
      send counter_pid, {:get_stats, self()}
      receive do
	{:return_stats, stats} ->
	  print_location_information(stats)
      end
    end)

    broadcast_sim_data(counter, location_info_list)
    
    Process.sleep(1000)

    IO.puts "============================================================"
    IO.puts "=========================tick:#{counter}=========================="
    IO.puts "============================================================"
    main_loop(counters, person_supervisor, tick_length, counter + (1000/tick_length))
  end
  
  @doc """
  Stops the simulation if the amount of infected is 0.
  ## Parameters:
  - stats: A list of the stats from all locations
  ## Returns:
  true if we have 0 infected else false.
  """

  def no_infected_left([%{"infected" => infected}]) do
    infected
  end

  def no_infected_left([%{"infected" => infected} | tail]) do
    infected + no_infected_left(tail)
  end
  
  @doc """
  Sends the updated data through a broadcast to the room "data"
  ## Parameters:
  - counter: int() the current "tick"
  - location_info_list: a list of every %Virus_sim.Location at the current "tick"
  """
  def broadcast_sim_data(counter, location_info_list) do
    data = (location_info_list) # Verkar som att poison inte behövs
    CoronaWeb.Endpoint.broadcast! "data", "sim_data", %{
      counter: counter,
      data: data,
    }
  end

  @doc """
  returns all of the information of the people at a location to  map (struct)
  ## Parameters:
  - location: Virus_sim.Location() the location we want to print info of
  """
  def print_location_information({location, type, infected, not_infected, dead, recovered}) do

    IO.puts("#{location}: infected: #{infected} not_infected: #{not_infected} dead: #{dead} recovered: #{recovered} total: #{infected + not_infected + dead + recovered}")
    
    %{"infected" => infected, "not_infected" => not_infected, "dead" => dead, "recovered" => recovered, "name" => location, "type" => type}   
  end

  @doc """
  Sends the main-processID to frontend so we can exit or pause the simulation from there. 
  ## Parameters: 
  - atom: The atom-name to be registered
  - pid: The pid to be registered
  """
  def send_pid_to_frontend(atom, pid) do
    Process.register(pid, atom)
    string_atom = Atom.to_string(atom)
    if pid == self() do
      CoronaWeb.Endpoint.broadcast! "data", "main_pid", %{
	string_atom: string_atom
      }
    else
      CoronaWeb.Endpoint.broadcast! "data", "person_supervisor_pid", %{
	string_atom: string_atom
      }
    end
  end
  
  @doc """
  Stops the simulation by exit the process registrered as atom.
  ## Parameters: 
  - atom: atom() The name of the process that will be exited.
  """
  def stop_sim(atom) do
    IO.puts "Simulation stopped"
    Process.exit(Process.whereis(atom), :exit)
  end
  
  @doc """
  Stops the simulation by calling Process.exit/2 on the main process
  """
  def stop_sim() do
    IO.puts "Simulation stopped"
    Process.exit(self(), :exit)
  end

  @doc """
  Sends a signal to every person in the simulation
  ## Parameters: 
  - person_supervisor: pid() person supervisor pid
  - signal: atom() signal to be sent
  """
  def send_to_all(person_supervisor, signal) do
    send person_supervisor, {:send_to_all, signal}
  end

  @doc """
  Determines how fast the program should run depending on the amount of people
  ## Parameters: 
  - no_people: integer() the number of person processes
  ## Returns:
  - integer() the length of a tick in milliseconds
  """
  def decide_tick_length(no_people) do
    cond do	
      no_people < 10001 ->
	50
      no_people < 25001 ->
	100
      no_people < 50001 ->
	200
      no_people < 100001 ->
	500
      true ->
	1000
    end
  end
end
