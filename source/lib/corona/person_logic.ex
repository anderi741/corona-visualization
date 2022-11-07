defmodule Person_logic do
  @moduledoc """
  All logic for a person
  """

  @doc """
  The control loop of a stateful person
  ## Parameters: 
  - person: %Virus_sim.Person{} The new state of the person 
  ## Messages:
  - {:get_infected, location_pid}: changes the status of a person to :infected
  - {:get_person, pid}: returns the person to sender
  - {:no_measures}: sets containment_measures to nil
  - {:social_distancing}: sets containment_measures to :social_distancing
  - {:lockdown}: sets containment_measures to :lockdown
  """
  def loop(person) do
    receive do	
      {:get_infected} ->
	if person.status == :not_infected do
	  send person.location.counter, {:infection}
	  new_stats = Map.put(person.stats, :infected, true)
	  person = update_person(person, {:stats, new_stats})
	  person = update_person(person, {:status, :infected})
	  {inc_time_low, inc_time_high} = person.incubation_time_range
	  loop(update_person(person, {:incubation_time, (Enum.random(inc_time_low..inc_time_high)) * 24})) # in days
	else
	  loop(person)
	end
      {:get_person, pid} ->
	send pid, {:return_person, person}
	loop(person)
      {:no_measures} ->
	person = update_person(person, {:containment_measures, nil})
	loop(person)
      {:social_distancing} ->
	person = update_person(person, {:containment_measures, :social_distancing})
	loop(person)
      {:lockdown} ->
	person = update_person(person, {:containment_measures, :lockdown})
	loop(person)
    after
      person.tick_length ->

	person = if person.status == :infected do
	  infect(person)
	else
	  person
	end
	
	person = if person.symptoms == nil or person.symptoms == :none do
	  calculate_move(person)
	else
	  if person.symptoms == :mild do
	    go_to(person, :home)
	  else #critical
	    go_to(person, :hospital)
	  end
	end
	
	person = if person.incubation_time == 0 do
	  if person.symptoms == nil do
	    catch_symptoms(person)
	  else
	    decide_fate(person)
	  end
	else
	  person
	end

	person = update_person(person, {:time, person.time + 1})
	
	if person.status == :infected do
	  loop(update_person(person, {:incubation_time,  person.incubation_time - 1}))
	else
	  loop(person)
	end
    end   
  end

  @doc """
  Gives a person who is infected symptoms depending on their immune_system
  
  ## Parameters:
  - person: Virus_sim.Person() a person struct
  ## Returns:
  - Virus_sim.Person(), modified if symptoms were given
  """

  def catch_symptoms(person) do
    {low, high} = person.incubation_time_range
    {death_rate, asymptomatic_rate} = person.severity_rates
    cond do
      person.immune_system > (100 - asymptomatic_rate) -> # asymptomatic_rate är antal % som inte visar symtom  
	person = update_person(person, {:symptoms, :none})
	update_person(person, {:incubation_time, (Enum.random(low..high) + 1) * 24})
	
      person.immune_system > death_rate -> # resten som har bättre immunförsvar än death_rate får milda symptom
	person = update_person(person, {:symptoms, :mild})
	update_person(person, {:incubation_time, (Enum.random(low*2..high*2) + 2) * 24}) 
	
      true ->
	person = update_person(person, {:symptoms, :critical})
	update_person(person, {:incubation_time, (Enum.random(low*2..high*2) + 2) * 24})
    end
  end

  @doc """
  Determines if a person should move to another location depending on the time_range left in the current location.

  ## Parameters:
  - person: Virus_sim.Person() a person struct
  ## Returns:
  - Virus_sim.Person(), modified location.time_range if not moved. Otherwise modified location
  """

  def calculate_move(person) do
    {low, high} = person.location.time_range
    if low != 1 do
      new_location = update_person(person.location, {:time_range, {low, high - 1}})
      new_location = update_person(new_location, {:time_range, {low - 1, high}})
      update_person(person, {:location, new_location})
    else
      left = high - low + 1
      rand = :rand.uniform(left)
      if rand == 1 do
	movement_logic(person)
      else
	new_location = update_person(person.location, {:time_range, {low, high - 1}})
	update_person(person, {:location, new_location})
      end
    end
  end

  @doc """
  Determines randomly where a person should move.
  
  ## Parameters:
  - person: Virus_sim.Person() a person struct
  ## Returns:
  - Virus_sim.Person(), modified if moved
  """

  def movement_logic(person) do
    r = :rand.uniform(100)
    list_types = case person.containment_measures do
      nil ->
	[{:work, 8}, {:store, 5}, {:park, 1}, {:restaurant, 3}, {:transport, 4}, {:gym, 2}, {:cinema, 2}] # Fixed weight for moving to a certain type of location
      :social_distancing ->
	[{:work, 4}, {:store, 5}, {:park, 1}, {:restaurant, 3}, {:transport, 4}, {:gym, 2}]
      :lockdown ->
	[{:work, 1}, {:store, 5}, {:transport, 3}]
      _ ->
	raise "failed case in movement_logic"
    end
    types = get_weighted_locations(list_types, person.location.type)

    case person.location.name do
      "Home" ->
	send person.important_pids.location_supervisor, {:get_random_location, self(), Enum.random(types)}
	receive do
	  {:return_random_location, []} -> # If the type didnt exist
	    person
	  {:return_random_location, {new_location, new_location_pid}} ->
	    move_update_person(person, new_location, new_location_pid)
	end
      _ ->
	cond do
	  (person.containment_measures == nil and r <= 80) or
	  (person.containment_measures == :social_distancing and r <= 60) or
	  (person.containment_measures == :lockdown and r <= 20) ->
	    send person.important_pids.location_supervisor, {:get_random_location, self(), Enum.random(types)}
	    receive do
	      {:return_random_location, []} -> # if the type didnt exist
person
	      {:return_random_location, {new_location, new_location_pid}} ->
		move_update_person(person, new_location, new_location_pid)
	    end
	  person.containment_measures == nil ->
	    move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {1, 16}}, nil) 
	  person.containment_measures == :social_distancing ->
	    move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {4, 24}}, nil)
	  person.containment_measures == :lockdown ->
	    move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {18, 64}}, nil)
	end	
    end
  end

  @doc """
  Moves a person the location specified
  
  ## Parameters: 
  - person: %Virus_sim.Person{} a person struct
  - place: The location we want to move to as an atom
  ## Returns: 
  - The moved person (if a move was possible)
  """
  def go_to(person, place) do
    case place do
      :graveyard ->
	person = move_update_person(person, %Virus_sim.Location{name: "Graveyard", counter: person.important_pids.graveyard_counter}, nil)
	send person.important_pids.person_supervisor, {:death_stats, person.stats}
	send person.location.counter, {:death}
	Process.exit(self(), :normal)
      :home ->
	if person.location.name != "Home" do
	  case person.containment_measures do
	    nil ->
	      move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {1, 16}}, nil)
	    :social_distancing ->
	      move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {4, 24}}, nil)
	    :lockdown ->
	      move_update_person(person, %Virus_sim.Location{name: "Home", counter: person.important_pids.home_counter, time_range: {18, 64}}, nil)
	  end
	else
	  person
	end
      :hospital ->
	if person.location.name != "Hospital" do
	  new_person = move_update_person(person, %Virus_sim.Location{name: "Hospital", counter: person.important_pids.hospital_counter}, nil)
	  if new_person == person do
	    go_to(person, :home)
	  else
	    new_stats = update_person(new_person.stats, {:healed, true})
	    update_person(new_person, {:stats, new_stats})
	  end
	else
	  person
	end
      _ ->
	raise "#{place} does not exist"
    end
  end
  
  @doc """
  Moves a person to a new location and remove it from the last location.
  
  ## Parameters: 
  - person: %Virus_sim.Person{} a person struct
  - new_location: %Virus_sim.Location{} the struct of the new location
  - new_location_pid: pid() the pid of the new location. If the new location is a counter-only location, this should be nil

  ## Returns:
  - person: %Virus_sim.Person{} The updated person struct with its new location
  """
  def move_update_person(person, new_location, nil) do
    send new_location.counter, {:move_in, self(), person.status}
    receive do
      {:successful_move, true} ->
	send person.location.counter, {:move_out, person.status}
	if person.location_pid != nil do
	  send person.location_pid, {:remove_person, self()}
	end	
	person = update_person(person, {:location, new_location})
	update_person(person, {:location_pid, nil})
	
      {:successful_move, false} ->
	person
    end
  end
  
  def move_update_person(person, new_location, new_location_pid) do
    send new_location.counter, {:move_in, self(), person.status}
    receive do
      {:successful_move, true} ->
	send person.location.counter, {:move_out, person.status}
	if person.location_pid != nil do
	  send person.location_pid, {:remove_person, self()}
	end	
	send new_location_pid, {:new_person, self()}
	person = update_person(person, {:location, new_location})
	update_person(person, {:location_pid, new_location_pid})
	
      {:successful_move, false} ->
	person
    end
  end
  
  @doc """
  
  Determines if a person should die or be recovered.
  The immune_system key inside the person struct decides the risk of dying.

  ## Hard-coded:
  - The chance of dying is set to 20%, if the immune_system is lower than 20%, the person will die.
  ## Parameters:
  - person: Virus_sim.Person() a person struct.
  ## Returns:
  - person: Virus_sim.Person() an updated person struct with either status: :dead or :recovered.
  """
  def decide_fate(person) do
    person = update_person(person, {:incubation_time, nil})
    if person.symptoms == :critical do
      if person.location.name == "Hospital" do
	send person.location.counter, {:recovery}
	person = update_person(person, {:status, :recovered})
	person = go_to(person, :home)
	update_person(person, {:symptoms, nil})
      else
	go_to(person, :graveyard)
      end
    else
      send person.location.counter, {:recovery}
      person = update_person(person, {:status, :recovered})
      update_person(person, {:symptoms, nil})
    end
  end

  @doc """
  Transforms a list of {location_type, amount} tuples into a list containing 'location_type' value times, without the location type that the person is currently in.

  ## Parameters: 
  - [{key, value} | tail]: List of tuples containing the location type and the amount of that type
  - current_type: atom() The type of the location that the person is currently in.
  
  ## Returns:
  [atom()] A list of location types
  """
  def get_weighted_locations([{key, value}], current_type) do
    if current_type == key do
      []
    else
      if value == 1 do
	[key]
      else
	[key | get_weighted_locations([{key, value - 1}], current_type)]
      end
    end
  end
  
  def get_weighted_locations([{key, value} | tail], current_type) do
    if current_type == key do
      get_weighted_locations(tail, current_type)
    else
      if value == 1 do
	[key | get_weighted_locations(tail, current_type)]
      else
	[key | get_weighted_locations([{key, value - 1} | tail], current_type)]
      end
    end
  end
  
  @doc """
  Determines randomly if the person infects others
  Sends an infect message to the location with probablilty "risk"
  ## Parameters:
  - person: the person struct
  ## Returns:
  - if an infection happened it returns the person with stats.infections + 1, otherwise returns person
  """
  def infect(person) do
    if person.location_pid == nil do
      person
    else
      r = :rand.uniform() #float between 0.0 and 1.0 with 16 digits
      infection_rate = if person.containment_measures != nil do
	(person.infection_rate * person.location.infection_rate)/200
      else
      (person.infection_rate * person.location.infection_rate)/100
      end
      if r <= infection_rate do
	send person.location_pid, {:infect, self()}
	new_stats = Map.put(person.stats, :infections, person.stats.infections + 1)
	update_person(person, {:stats, new_stats})
      else
	person
      end
    end
  end
  
  @doc """
  Updates the state of a person
  
  ## Parameters:
  - person: Virus_sim.Person() a person struct.
  - {key, value}: The key and the value to be updated.
  ## Returns:
  - person: The new updated person struct
  """
  def update_person(person, {key, value}) do
    Map.put(person, key, value)
  end
end
