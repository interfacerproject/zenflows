# SPDX-License-Identifier: AGPL-3.0-or-later
# Zenflows is software that implements the Valueflows vocabulary.
# Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
# Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

%{configs: [%{
	name: "default",
	files: %{
		included: [
			".credo.exs",
			".iex.exs",
			"mix.exs",
			"src/",
			"test/",
			"priv/",
		],
		excluded: [~r"/_build/", ~r"/deps/"],
	},
	strict: true,
	color: false,
	checks: [
		# consistency
		{Credo.Check.Consistency.ExceptionNames, []},
		{Credo.Check.Consistency.LineEndings, []},
		{Credo.Check.Consistency.ParameterPatternMatching, []},
		{Credo.Check.Consistency.SpaceAroundOperators, []},
		{Credo.Check.Consistency.SpaceInParentheses, []},
		{Credo.Check.Consistency.TabsOrSpaces, [force: :tabs]},

		# design
		{Credo.Check.Design.AliasUsage, [priority: :low, if_nested_deeper_than: 3, if_called_more_often_than: 1]},
		{Credo.Check.Design.TagTODO, [exit_status: 2]},
		{Credo.Check.Design.TagFIXME, []},

		# readability
		{Credo.Check.Readability.AliasOrder, []},
		{Credo.Check.Readability.FunctionNames, []},
		{Credo.Check.Readability.LargeNumbers, []},
		{Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
		{Credo.Check.Readability.ModuleAttributeNames, []},
		{Credo.Check.Readability.ModuleDoc, []},
		{Credo.Check.Readability.ModuleNames, files: %{excluded: ["priv/repo/migrations/*.exs"]}},
		{Credo.Check.Readability.ParenthesesInCondition, []},
		{Credo.Check.Readability.ParenthesesOnZeroArityDefs, [parens: true]},
		{Credo.Check.Readability.PredicateFunctionNames, []},
		{Credo.Check.Readability.PreferImplicitTry, []},
		{Credo.Check.Readability.RedundantBlankLines, []},
		{Credo.Check.Readability.Semicolons, []},
		{Credo.Check.Readability.SpaceAfterCommas, []},
		{Credo.Check.Readability.StringSigils, []},
		{Credo.Check.Readability.TrailingBlankLine, []},
		{Credo.Check.Readability.TrailingWhiteSpace, []},
		{Credo.Check.Readability.UnnecessaryAliasExpansion, []},
		{Credo.Check.Readability.VariableNames, []},

		# refactoring
		{Credo.Check.Refactor.CondStatements, []},
		{Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 16]},
		{Credo.Check.Refactor.FunctionArity, []},
		{Credo.Check.Refactor.LongQuoteBlocks, []},
		# {Credo.Check.Refactor.MapInto, []},
		{Credo.Check.Refactor.MatchInCondition, []},
		{Credo.Check.Refactor.NegatedConditionsInUnless, []},
		{Credo.Check.Refactor.NegatedConditionsWithElse, []},
		{Credo.Check.Refactor.Nesting, [max_nesting: 5]},
		{Credo.Check.Refactor.UnlessWithElse, []},
		{Credo.Check.Refactor.WithClauses, []},

		# warnings
		{Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
		{Credo.Check.Warning.BoolOperationOnSameValues, []},
		{Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
		{Credo.Check.Warning.IExPry, []},
		{Credo.Check.Warning.IoInspect, []},
		#{Credo.Check.Warning.LazyLogging, []},
		{Credo.Check.Warning.MixEnv, false},
		{Credo.Check.Warning.OperationOnSameValues, []},
		{Credo.Check.Warning.OperationWithConstantResult, []},
		{Credo.Check.Warning.RaiseInsideRescue, []},
		{Credo.Check.Warning.UnusedEnumOperation, []},
		{Credo.Check.Warning.UnusedFileOperation, []},
		{Credo.Check.Warning.UnusedKeywordOperation, []},
		{Credo.Check.Warning.UnusedListOperation, []},
		{Credo.Check.Warning.UnusedPathOperation, []},
		{Credo.Check.Warning.UnusedRegexOperation, []},
		{Credo.Check.Warning.UnusedStringOperation, []},
		{Credo.Check.Warning.UnusedTupleOperation, []},
		{Credo.Check.Warning.UnsafeExec, []},

		# controversial and experimental
		{Credo.Check.Consistency.MultiAliasImportRequireUse, false},
		{Credo.Check.Consistency.UnusedVariableNames, false},
		{Credo.Check.Design.DuplicatedCode, false},
		{Credo.Check.Readability.AliasAs, false},
		{Credo.Check.Readability.BlockPipe, false},
		{Credo.Check.Readability.ImplTrue, false},
		{Credo.Check.Readability.MultiAlias, false},
		{Credo.Check.Readability.SeparateAliasRequire, false},
		{Credo.Check.Readability.SinglePipe, false},
		{Credo.Check.Readability.Specs, false},
		{Credo.Check.Readability.StrictModuleLayout, false},
		{Credo.Check.Readability.WithCustomTaggedTuple, false},
		{Credo.Check.Refactor.ABCSize, false},
		{Credo.Check.Refactor.AppendSingleItem, false},
		{Credo.Check.Refactor.DoubleBooleanNegation, false},
		{Credo.Check.Refactor.ModuleDependencies, false},
		{Credo.Check.Refactor.NegatedIsNil, false},
		{Credo.Check.Refactor.PipeChainStart, false},
		{Credo.Check.Refactor.VariableRebinding, false},
		{Credo.Check.Warning.LeakyEnvironment, false},
		{Credo.Check.Warning.MapGetUnsafePass, false},
		{Credo.Check.Warning.UnsafeToAtom, false},
	],
}]}
