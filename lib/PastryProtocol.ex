defmodule PastryProtocol do
  use GenServer
  
  @name :master
  @base 4

  def prefixSimilarity(n1, n2, bit_pos) do
    if String.first(n1) != String.first(n2) do
      bit_pos
    else
      prefixSimilarity(String.slice(n1, 1..(String.length(n1)-1)), String.slice(n2, 1..(String.length(n2)-1)), bit_pos+1)
    end   
  end

  def baseStringConversion(node_id, length) do
    base_node_id = Integer.to_string(node_id, @base)
     String.pad_leading(base_node_id, length, "0")
  end

  def getNearestNode([neighbor | rest], to_id, nearest_node, difference) do
    if(abs(to_id - neighbor) < difference) do
      nearest_node=neighbor
      difference = abs(to_id - neighbor)
    end
    getNearestNode(rest, to_id, nearest_node, difference)
  end
    
    def getNearestNode([], to_id, nearest_node, difference) do
      {nearest_node, difference}
    end

  def addTableEntries(curr_node_id, first_entries, no_of_bits, min_leaf_set, max_leaf_set, routing_table) do
    if length(first_entries) == 0 do
      {min_leaf_set, max_leaf_set, routing_table}
    else
      node_id = List.first(first_entries)       
      max_leaf_set = if (node_id > curr_node_id && !Enum.member?(max_leaf_set, node_id)) do
        if(length(max_leaf_set) < 4) do
          max_leaf_set ++ [node_id]            
        else
          if (node_id < Enum.max(max_leaf_set)) do
            max_leaf_set = List.delete(max_leaf_set, Enum.max(max_leaf_set))
            max_leaf_set ++ [node_id]              
          else
            max_leaf_set
          end
        end
      else
        max_leaf_set
      end
      min_leaf_set = if (!Enum.member?(min_leaf_set, node_id) && node_id < curr_node_id ) do
        if(length(min_leaf_set) < 4) do
          min_leaf_set ++ [node_id]
        else
          if (node_id > Enum.min(min_leaf_set)) do
            min_leaf_set = List.delete(min_leaf_set, Enum.min(min_leaf_set))
              min_leaf_set ++ [node_id]
          else
            min_leaf_set
          end
        end
      else
        min_leaf_set
      end      
      
      similar_pref = prefixSimilarity(baseStringConversion(curr_node_id, no_of_bits), baseStringConversion(node_id, no_of_bits), 0)
      next_bit = String.to_integer(String.at(baseStringConversion(node_id, no_of_bits), similar_pref))
      routing_table = if elem(elem(routing_table, similar_pref), next_bit) == -1 do
        row_elem = elem(routing_table, similar_pref)
        added_row = Tuple.insert_at(Tuple.delete_at(row_elem, next_bit), next_bit, node_id)
        Tuple.insert_at(Tuple.delete_at(routing_table, similar_pref), similar_pref, added_row)
      else
        routing_table
      end
        addTableEntries(curr_node_id, List.delete_at(first_entries, 0), no_of_bits, min_leaf_set, max_leaf_set, routing_table)
    end
  end

  def notifyNodes(routing_table, i, j, no_of_bits, curr_node_id, no_returns) do
    if i >= no_of_bits or j >= 4 do
      no_returns
    else
      node = elem(elem(routing_table, i), j)
      if node != -1 do
        no_returns=no_returns+1
        GenServer.cast(String.to_atom("child"<>Integer.to_string(node)), {:update, curr_node_id})
      end
      no_returns = notifyNodes(routing_table, i, j + 1, no_of_bits, curr_node_id, no_returns)
      if j == 0 do
        no_returns = notifyNodes(routing_table, i + 1, j, no_of_bits, curr_node_id, no_returns)
      end
      no_returns
    end
  end

  def sendRequest([i | remaining_items], curr_node_id, node_id_space) do
    Process.sleep(1000)
    neighbor_list = Enum.to_list(0..node_id_space-1)
    destination = Enum.random(List.delete(neighbor_list, curr_node_id))
    GenServer.cast(String.to_atom("child"<>Integer.to_string(curr_node_id)), {:route, "Route", curr_node_id, destination, 0})
    sendRequest(remaining_items, curr_node_id, node_id_space)
  end

  def sendRequest([], curr_node_id, node_id_space) do
    {:ok}
  end

  def startLink(node_id, no_of_nodes) do
    node_name = String.to_atom("child"<>Integer.to_string(node_id))
    GenServer.start_link(PastryProtocol, [node_id, no_of_nodes], name: node_name)
  end

  def init([node_id, no_of_nodes]) do  
    no_of_bits = Float.ceil(:math.log(no_of_nodes)/:math.log(@base))
    no_of_bits = round(no_of_bits)   
    table_row = Tuple.duplicate(-1, @base)
    routing_table = Tuple.duplicate(table_row, no_of_bits)
    no_returns = 0
    {:ok, {node_id, no_of_nodes, [], [], routing_table, no_returns}}
  end

  def handle_cast({:route, message, from_id, to_id, hops}, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_of_bits = round(Float.ceil(:math.log(no_of_nodes)/:math.log(@base)))
    node_id_space = round(Float.ceil(:math.pow(@base, no_of_bits)))

    if  message=="Join" do
        similar_pref = prefixSimilarity(baseStringConversion(curr_id, no_of_bits), baseStringConversion(to_id, no_of_bits), 0)
        next_bit = String.to_integer(String.at(baseStringConversion(to_id, no_of_bits), similar_pref))
        if(hops == 0 && similar_pref > 0) do
          for i <- 0..(similar_pref-1) do
          GenServer.cast(String.to_atom("child"<>Integer.to_string(to_id)), {:add_new_row, i, elem(routing_table,i)})
          end
        end
        GenServer.cast(String.to_atom("child"<>Integer.to_string(to_id)), {:add_new_row, similar_pref, elem(routing_table, similar_pref)})

      cond do
        (length(min_leaf_set)>0 && to_id >= Enum.min(min_leaf_set) && to_id <= curr_id) || (length(max_leaf_set)>0 && to_id <= Enum.max(max_leaf_set) && to_id >= curr_id) ->        
          difference = node_id_space + 10
          nearest_node=-1
          {nearest_node,difference} = if(to_id < curr_id) do
                getNearestNode(min_leaf_set, to_id, nearest_node, difference)
          else 
                getNearestNode(max_leaf_set, to_id, nearest_node, difference)
          end

          if(abs(to_id - curr_id) > difference) do
            GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest_node)), {:route,message,from_id,to_id,hops+1}) 
          else 
            leaf_set = [curr_id] ++ min_leaf_set ++ max_leaf_set
            GenServer.cast(String.to_atom("child"<>Integer.to_string(to_id)), {:add_leaf,leaf_set})
          end       
        length(min_leaf_set)<4 && length(min_leaf_set)>0 && to_id < Enum.min(min_leaf_set) ->
          GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(min_leaf_set))), {:route,message,from_id,to_id,hops+1})
        length(max_leaf_set)<4 && length(max_leaf_set)>0 && to_id > Enum.max(max_leaf_set) ->
          GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(max_leaf_set))), {:route,message,from_id,to_id,hops+1})
        (length(min_leaf_set)==0 && to_id<curr_id) || (length(max_leaf_set)==0 && to_id>curr_id) -> 
          
          leaf_set = [curr_id] ++ min_leaf_set ++ max_leaf_set 
          GenServer.cast(String.to_atom("child"<>Integer.to_string(to_id)), {:add_leaf,leaf_set})
        elem(elem(routing_table, similar_pref), next_bit) != -1 ->
          
          GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, similar_pref), next_bit))), {:route,message,from_id,to_id,hops+1})
        to_id > curr_id ->
          GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(max_leaf_set))), {:route,message,from_id,to_id,hops+1})
        
        to_id < curr_id ->
          GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(min_leaf_set))), {:route,message,from_id,to_id,hops+1})
        
        true ->
          IO.puts("Impossible")
      end
    else
        if curr_id == to_id do
          GenServer.cast(:global.whereis_name(@name), {:finish_route,hops+1})
        else 
          similar_pref = prefixSimilarity(baseStringConversion(curr_id, no_of_bits), baseStringConversion(to_id, no_of_bits), 0)
          next_bit = String.to_integer(String.at(baseStringConversion(to_id, no_of_bits), similar_pref))
        cond do
          
          (length(min_leaf_set)>0 && to_id >= Enum.min(min_leaf_set) && to_id < curr_id) || (length(max_leaf_set)>0 && to_id <= Enum.max(max_leaf_set) && to_id > curr_id) ->
            difference=node_id_space + 10
            nearest_node=-1
            {nearest_node,difference} = if(to_id < curr_id) do
              getNearestNode(min_leaf_set, to_id, nearest_node, difference)
          else 
              getNearestNode(max_leaf_set, to_id, nearest_node, difference)
          end

            if(abs(to_id - curr_id) > difference) do
              GenServer.cast(String.to_atom("child"<>Integer.to_string(nearest_node)), {:route,"Route",from_id,to_id,hops+1})
            else 
              GenServer.cast(:global.whereis_name(@name), {:finish_route,hops+1})
            end                      
            
            length(min_leaf_set)<4 && length(min_leaf_set)>0 && to_id < Enum.min(min_leaf_set) ->
              GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(min_leaf_set))), {:route,"Route",from_id,to_id,hops+1})
            length(max_leaf_set)<4 && length(max_leaf_set)>0 && to_id > Enum.max(max_leaf_set) ->
              GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(max_leaf_set))), {:route,"Route",from_id,to_id,hops+1})
            (length(min_leaf_set)==0 && to_id<curr_id) || (length(max_leaf_set)==0 && to_id>curr_id) -> 
              GenServer.cast(:global.whereis_name(@name), {:finish_route,hops+1})
              elem(elem(routing_table, similar_pref), next_bit) != -1 ->
              GenServer.cast(String.to_atom("child"<>Integer.to_string(elem(elem(routing_table, similar_pref), next_bit))), {:route,"Route",from_id,to_id,hops+1})
            to_id > curr_id ->
              GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.max(max_leaf_set))), {:route,"Route",from_id,to_id,hops+1})
            to_id < curr_id ->
              GenServer.cast(String.to_atom("child"<>Integer.to_string(Enum.min(min_leaf_set))), {:route,"Route",from_id,to_id,hops+1})
            true ->
              IO.puts("Impossible")
        end       
      end 
    end  
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end
  
  def handle_cast({:add_new_row,row_no,row_new}, state) do 
      {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
      routing_table =  Tuple.insert_at(Tuple.delete_at(routing_table, row_no), row_no, row_new)  
      {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end

  def handle_cast({:initiatePastry, first_entries}, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_of_bits = round(Float.ceil(:math.log(no_of_nodes)/:math.log(@base)))
    first_entries = List.delete(first_entries, curr_id)
    {min_leaf_set, max_leaf_set, routing_table} = addTableEntries(curr_id, first_entries, no_of_bits, min_leaf_set, max_leaf_set, routing_table)

    for i <- 0..(no_of_bits-1) do
      next_bit = String.to_integer(String.at(baseStringConversion(curr_id, no_of_bits), i))
      row = elem(routing_table, i)
      row_updated = Tuple.insert_at(Tuple.delete_at(row, next_bit), next_bit, curr_id)
      Tuple.insert_at(Tuple.delete_at(routing_table, i), i, row_updated)
    end

    GenServer.cast(:global.whereis_name(@name), :complete_join)
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end

  def handle_cast({:add_leaf, leaf_set}, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_of_bits = round(Float.ceil(:math.log(no_of_nodes)/:math.log(@base)))
    {min_leaf_set, max_leaf_set, routing_table} = addTableEntries(curr_id, leaf_set, no_of_bits, min_leaf_set, max_leaf_set, routing_table)
    for i <- min_leaf_set do
          GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update, curr_id})
    end
    for i <- max_leaf_set do
          GenServer.cast(String.to_atom("child"<>Integer.to_string(i)), {:update, curr_id})
    end
    no_returns = no_returns + length(min_leaf_set) + length(max_leaf_set)
      no_returns = notifyNodes(routing_table, 0, 0, no_of_bits, curr_id, no_returns)
    for i <- 0..(no_of_bits-1) do
      for j <- 0..3 do
        row = elem(routing_table, i)
        row_updated = Tuple.insert_at(Tuple.delete_at(row, j), j, curr_id)
        Tuple.insert_at(Tuple.delete_at(routing_table, i), i, row_updated)
      end
    end
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end

  def handle_cast({:start_routing, no_of_reqs}, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_of_bits = round(Float.ceil(:math.log(no_of_nodes)/:math.log(@base)))
    node_id_space = round(Float.ceil(:math.pow(@base, no_of_bits)))
    sendRequest(Enum.to_list(1..no_of_reqs), curr_id, node_id_space)
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end

  def handle_cast(:ack, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_returns = no_returns - 1
    if(no_returns == 0) do
      GenServer.cast(:global.whereis_name(@name), :complete_join)
    end
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end

  def handle_cast({:update, new_node}, state) do
    {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns} = state
    no_of_bits = Float.ceil(:math.log(no_of_nodes)/:math.log(@base))
    no_of_bits = round(no_of_bits)
    {min_leaf_set, max_leaf_set, routing_table} = addTableEntries(curr_id, [new_node], no_of_bits, min_leaf_set, max_leaf_set, routing_table)
    GenServer.cast(String.to_atom("child"<>Integer.to_string(new_node)), :ack)
    {:noreply, {curr_id, no_of_nodes, min_leaf_set, max_leaf_set, routing_table, no_returns}}
  end
end