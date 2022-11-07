defmodule Location_logic do
  @moduledoc """
  All logic for locations
  """

  @doc """
  The control loop of a stateful location
  ## Parameters: 
  - location: %Virus_sim.Location{} The new state of the location 
  ## Messages:
  - {:new_person, pid}: insert a new person with pid "pid" in the location
  - {:get_location, pid}: returns the location struct to the sender
  - {:get_location_no_list, pid}: returns the location struct to the sender with an empty loaction_list
  - {:infect, pid}: picks a random person from the location and sends a get_infected message to it
  - {:remove_person, pid}: removes a person with pid "pid" from the location
  """
  def loop(location) do
    receive do
      {:new_person, pid} ->
        list = [pid | location.location_list]
        loop(update_location(location, {:location_list, list}))

      {:get_location, pid} ->
        send(pid, {:return_location, location})
        loop(location)

      {:get_location_no_list, pid} ->
	send(pid, {:return_location, update_location(location, {:location_list, []})})
	loop(location)

      {:infect, pid} ->
        infect_person(location.location_list, pid)
        loop(location)

      {:remove_person, pid} ->
        list = List.delete(location.location_list, pid)
        loop(update_location(location, {:location_list, list}))

    end

    loop(location)
  end

  @doc """
  Helperfunction for infect message. Picks a random person from the location and sends a get_infected message to it, calls itself recursively if the person infecting was picked.
  ## Parameters:
  - to_infect: the pid in the list if there is only one pid
  - location: %Virus_sim.Location{} The state of the location
  . pid: pid() The pid person doing the infecting
  """
  def infect_person([to_infect], pid) do
    if to_infect == pid do
      :ok
    else
      send to_infect, {:get_infected}
    end
  end
  
  def infect_person(location_list, pid) do
    to_infect = Enum.random(location_list)

    if to_infect == pid do
      infect_person(location_list, pid)
    else
      send to_infect, {:get_infected}
    end
  end

  @doc """
  Updates the state of a location
  
  ## Parameters:
  - location: Virus_sim.Location() a location struct.
  - {key, value}: The key and the value to be updated.
  ## Returns:
  - location: The new updated location struct
  """
  def update_location(location, {key, value}) do
    Map.put(location, key, value)
  end
  
end
