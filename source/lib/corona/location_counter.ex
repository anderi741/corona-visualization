defmodule Location_counter do
  @moduledoc """
  Stores the stats of a location
  """

  @doc """
  The control loop of a stateful counter_supervisor.
  ## Parameters:
  - counter: %Virus_sim.Location_counter struct with all the information about a location
  
  ## Messages:
  - :infection: adds an infected person and removes a not_infected person from the counter
  - :recovery: adds a recovered person and removes an infected person from the counter
  - :death: adds a dead person and removes an infected person from the counter
  - :move_out: removes a person from the counter
  - :move_in: checks if the max_capacity is reached and if not adds a person to the counter, then returns :true or :false  
  - :get_stats: returns the location name and the amount of all people in the location separated with their statuses in a tuple.
  - :update_cap: updates the max capacity of a location
  """
  def loop(counter) do
    receive do
      {:infection} ->
	counter = update_counter(counter, {:i, counter.i+1})
	counter = update_counter(counter, {:n, counter.n-1})
	loop(counter)
	
      {:recovery} ->
	counter = update_counter(counter, {:i, counter.i-1})
	counter = update_counter(counter, {:r, counter.r+1})
	loop(counter)
	
      {:death} ->
	counter = update_counter(counter, {:i, counter.i-1})
	counter = update_counter(counter, {:d, counter.d+1})
	loop(counter)
	
      {:move_out, status} ->
	case status do
	  :infected ->
	    counter = update_counter(counter, {:i, counter.i-1})
	    loop(counter)
	  :not_infected ->
	    counter = update_counter(counter, {:n, counter.n-1})
	    loop(counter)
	  :dead ->
	    counter = update_counter(counter, {:d, counter.d-1})
	    loop(counter)
	  :recovered ->
	    counter = update_counter(counter, {:r, counter.r-1})
	    loop(counter)
	  _->
	    raise "failed case"
	end

      {:move_in, status} ->
	case status do
	  :infected ->
	    counter = update_counter(counter, {:i, counter.i+1})
	    loop(counter)
	  :not_infected ->
	    counter = update_counter(counter, {:n, counter.n+1})
	    loop(counter)
	  :dead ->
	    counter = update_counter(counter, {:d, counter.d+1})
	    loop(counter)
	  :recovered ->
	    counter = update_counter(counter, {:r, counter.r+1})
	    loop(counter)
	  _->
	    raise "failed case"
	end
	
      {:move_in, pid, status} ->
	if (counter.max_cap == nil) or (counter.i+counter.n+counter.d+counter.r < counter.max_cap) do
	  send pid, {:successful_move, true}
	  case status do
	    :infected ->
	      counter = update_counter(counter, {:i, counter.i+1})
	      loop(counter)
	    :not_infected ->
	      counter = update_counter(counter, {:n, counter.n+1})
	      loop(counter)
	    :dead ->
	      counter = update_counter(counter, {:d, counter.d+1})
	      loop(counter)
	    :recovered ->
	      counter = update_counter(counter, {:r, counter.r+1})
	      loop(counter)
	    _->
	      raise "failed case"
	  end
	else
	  send pid, {:successful_move, false}
	  loop(counter)
	end

      {:get_stats, pid} ->
	send pid, {:return_stats, {counter.name, counter.type, counter.i, counter.n, counter.d, counter.r}}
	loop(counter)
      {:get_cap, pid} ->
	send pid, {:return_cap, counter.max_cap}
	loop(counter)
      {:update_cap, cap} ->
	counter = update_counter(counter, {:max_cap, cap})
	loop(counter)
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
  def update_counter(counter, {key, value}) do
    Map.put(counter, key, value)
  end
end
