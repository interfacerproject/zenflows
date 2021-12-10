defmodule Zenflows.Valflow.ActionEnum do
@moduledoc """
Custom Ecto type for Action definitions in schemas.
"""
use Ecto.Type

#alias Zenflows.Valflow.Action

@type t() :: :produce | :use | :consume | :cite | :work
	| :pickup | :dropoff | :accept | :modify
	| :pack | :unpack | :transfer_all_rights
	| :transfer_custody | :transfer | :move
	| :raise | :lower

@spec values() :: [t(), ...]
def values() do
	~w[
		produce use consume cite work
		pickup dropoff accept modify
		pack unpack transfer_all_rights
		transfer_custody transfer move
		raise lower
	]a
end

@impl true
def type() do
	:string
end

@impl true
def cast(:produce), do: {:ok, :produce}
def cast(:use), do: {:ok, :use}
def cast(:consume), do: {:ok, :consume}
def cast(:cite), do: {:ok, :cite}
def cast(:work), do: {:ok, :work}
def cast(:pickup), do: {:ok, :pickup}
def cast(:dropoff), do: {:ok, :dropoff}
def cast(:accept), do: {:ok, :accept}
def cast(:modify), do: {:ok, :modify}
def cast(:pack), do: {:ok, :pack}
def cast(:unpack), do: {:ok, :unpack}
def cast(:transfer_all_rights), do: {:ok, :transfer_all_rights}
def cast(:transfer_custody), do: {:ok, :transfer_custody}
def cast(:transfer), do: {:ok, :transfer}
def cast(:move), do: {:ok, :move}
def cast(:raise), do: {:ok, :raise}
def cast(:lower), do: {:ok, :lower}
def cast(_), do: :error

@impl true
#def dump(%Action{id: :produce}), do: {:ok, "produce"}
#def dump(%Action{id: :use}), do: {:ok, "use"}
#def dump(%Action{id: :consume}), do: {:ok, "consume"}
#def dump(%Action{id: :cite}), do: {:ok, "cite"}
#def dump(%Action{id: :work}), do: {:ok, "work"}
#def dump(%Action{id: :pickup}), do: {:ok, "pickup"}
#def dump(%Action{id: :dropoff}), do: {:ok, "dropoff"}
#def dump(%Action{id: :accept}), do: {:ok, "accept"}
#def dump(%Action{id: :modify}), do: {:ok, "modify"}
#def dump(%Action{id: :pack}), do: {:ok, "pack"}
#def dump(%Action{id: :unpack}), do: {:ok, "unpack"}
#def dump(%Action{id: :transfer_all_rights}), do: {:ok, "transfer_all_rights"}
#def dump(%Action{id: :transfer_custody}), do: {:ok, "transfer_custody"}
#def dump(%Action{id: :transfer}), do: {:ok, "transfer"}
#def dump(%Action{id: :move}), do: {:ok, "move"}
#def dump(%Action{id: :raise}), do: {:ok, "raise"}
#def dump(%Action{id: :lower}), do: {:ok, "lower"}
def dump(:produce), do: {:ok, "produce"}
def dump(:use), do: {:ok, "use"}
def dump(:consume), do: {:ok, "consume"}
def dump(:cite), do: {:ok, "cite"}
def dump(:work), do: {:ok, "work"}
def dump(:pickup), do: {:ok, "pickup"}
def dump(:dropoff), do: {:ok, "dropoff"}
def dump(:accept), do: {:ok, "accept"}
def dump(:modify), do: {:ok, "modify"}
def dump(:pack), do: {:ok, "pack"}
def dump(:unpack), do: {:ok, "unpack"}
def dump(:transfer_all_rights), do: {:ok, "transfer_all_rights"}
def dump(:transfer_custody), do: {:ok, "transfer_custody"}
def dump(:transfer), do: {:ok, "transfer"}
def dump(:move), do: {:ok, "move"}
def dump(:raise), do: {:ok, "raise"}
def dump(:lower), do: {:ok, "lower"}
def dump(_), do: :error

@impl true
def load("produce"), do: {:ok, :produce}
def load("use"), do: {:ok, :use}
def load("consume"), do: {:ok, :consume}
def load("cite"), do: {:ok, :cite}
def load("work"), do: {:ok, :work}
def load("pickup"), do: {:ok, :pickup}
def load("dropoff"), do: {:ok, :dropoff}
def load("accept"), do: {:ok, :accept}
def load("modify"), do: {:ok, :modify}
def load("pack"), do: {:ok, :pack}
def load("unpack"), do: {:ok, :unpack}
def load("transfer_all_rights"), do: {:ok, :transfer_all_rights}
def load("transfer_custody"), do: {:ok, :transfer_custody}
def load("transfer"), do: {:ok, :transfer}
def load("move"), do: {:ok, :move}
def load("raise"), do: {:ok, :raise}
def load("lower"), do: {:ok, :lower}
def load(_), do: :error

#defp actions() do
#	%{
#		produce: %Action{
#			id: :produce,
#			label: :produce,
#			resource_effect: :increment,
#			onhand_effect: :increment,
#			input_output: :output,
#			pairs_with: :not_applicable,
#		},
#		use: %Action{
#			id: :use,
#			label: :use,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :input,
#			pairs_with: :not_applicable,
#		},
#		consume: %Action{
#			id: :consume,
#			label: :consume,
#			resource_effect: :decrement,
#			onhand_effect: :decrement,
#			input_output: :input,
#			pairs_with: :not_applicable,
#		},
#		cite: %Action{
#			id: :cite,
#			label: :cite,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :input,
#			pairs_with: :not_applicable,
#		},
#		work: %Action{
#			id: :work,
#			label: :work,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :input,
#			pairs_with: :not_applicable,
#		},
#		pickup: %Action{
#			id: :pickup,
#			label: :pickup,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :input,
#			pairs_with: :dropoff,
#		},
#		dropoff: %Action{
#			id: :dropoff,
#			label: :dropoff,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :output,
#			pairs_with: :pickup,
#		},
#		accept: %Action{
#			id: :accept,
#			label: :accept,
#			resource_effect: :no_effect,
#			onhand_effect: :input,
#			input_output: :not_applicable,
#			pairs_with: :modify,
#		},
#		modify: %Action{
#			id: :modify,
#			label: :modify,
#			resource_effect: :no_effect,
#			onhand_effect: :no_effect,
#			input_output: :output,
#			pairs_with: :modify,
#		},
#		pack: %Action{
#			id: :pack,
#			label: :pack,
#			resource_effect: :no_effect,
#			onhand_effect: :decrement,
#			input_output: :input,
#			pairs_with: :modify,
#		},
#		unpack: %Action{
#			id: :unpack,
#			label: :unpack,
#			resource_effect: :no_effect,
#			onhand_effect: :increment,
#			input_output: :output,
#			pairs_with: :accept,
#		},
#		transfer_all_rights: %Action{
#			id: :transfer_all_rights,
#			label: :transfer_all_rights,
#			resource_effect: :decrement_increment,
#			onhand_effect: :no_effect,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#		transfer_custody: %Action{
#			id: :transfer_custody,
#			label: :transfer_custody,
#			resource_effect: :no_effect,
#			onhand_effect: :decrement_increment,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#		transfer: %Action{
#			id: :transfer,
#			label: :transfer,
#			resource_effect: :decrement_increment,
#			onhand_effect: :decrement_increment,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#		move: %Action{
#			id: :move,
#			label: :move,
#			resource_effect: :decrement_increment,
#			onhand_effect: :decrement_increment,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#		raise: %Action{
#			id: :raise,
#			label: :raise,
#			resource_effect: :increment,
#			onhand_effect: :increment,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#		lower: %Action{
#			id: :lower,
#			label: :lower,
#			resource_effect: :decrement,
#			onhand_effect: :decrement,
#			input_output: :not_applicable,
#			pairs_with: :not_applicable,
#		},
#	}
#end
end
