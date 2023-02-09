<!--
SPDX-License-Identifier: AGPL-3.0-or-later
Zenflows is software that implements the Valueflows vocabulary.
Zenflows is designed, written, and maintained by srfsh <srfsh@dyne.org>
Copyright (C) 2021-2023 Dyne.org foundation <foundation@dyne.org>.

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->

# VF Intro

This document tries to explain how to use Zenflows's implementaton of the
Valueflows vocabulary.  Please read about Valueflows documentation a bit to grasp
some concepts such as *Processes*, *EconomicEvents*, *EconomicResources*, and
*ResourceSpecifications* in order for this document to be more effective.


## Ownership and Quanty Types of Resources

There are two quantity types in Zenflows:

* `accountingQuantity`
* `onhandQuantity`

Their meaning is defined by how they are used by the events.  For example:

* `produce` and `raise` events increase both quantities
* `consume` and `lower` events decrease both quantities
* `accept` events decrease `onhandQuantity`
* `modify` events increase `onhandQuantity`
* `transferAllRights` events decrease `accountingQuantity` of one resource, and
  increase `accountingQuantity` of the other resource

The ownership types specify who is the owner of the given quantity type.  Those
types are:

* `primaryAccountable`: the owner of the quantity `accountingQuantity`
* `custodian`: the current owner who has custody over the resource, amounted by
  `onhandQuantity`


## ResourceSpecification and ProcessSpecification

In order to tell what a resource is, we use *ResourceSpecifications*.  If two
resources conform to the same ResourceSpecification, they would be of the same
type.  Each resource has a field named `conformsTo` that points to a
ResourceSpecification.  The field gets set by `resourceConformsTo` of `produce`
and `raise` events.

But sometimes ResourceSpecification is not enough to differentiate between other
resources.  Sometimes you need to, for example, differentiate between "clean",
"used", "dirty", "donated" gown resources.  You use ProcessSpecifications to
differentiate between those.  Each resource has a field named `stage` that could
point to a ProcessSpecification.  The field gets set by `modify` events.


## Event Side-Effects and Enforcements

In Zenflows, each event has its own requirements, enforcements, and possible
side-effects.  Even though the GraphQL types allow some fields optionally,
depending on the action, the back-end enforces some fields required by the
events.


### Common Requirements and Enforcements

Each event requires an Action.  If no Action is provided, the back-end can't
know which fields to enforce and which side-effects to create.  The supported
Actions are:

* `produce`
* `consume`
* `use`
* `work`
* `cite`
* `deliverService` (alias: `deliver-service`)
* `pickup`
* `dropoff`
* `accept`
* `modify`
* `pack`
* `unpack`
* `transferCustody` (alias: `transfer-custody`)
* `transferAllRights` (alias: `transfer-all-rights`)
* `transfer`
* `move`
* `raise`
* `lower`

Each event requires a `provider` and a `receiver`.  If any of them is not
provided, the back-end will default to the currently logged-in agent.  This
might be changed in the future, however (the front-ends can default to currently
logged-in agent by themselves).  Also, at the moment, `provider` must be the
same agent as the logged-in agent.

Each event requires you to provide some sort of time-related data.  These are
provided by the fields `hasPointInTime`, `hasBeginning`, and `hasEnd`.  The
back-end allows only these mutually-exclusive combinations, and if none of these
combinations are met, you'll not be able to create your event:

* Only `hasPointInTime`
* Only `hasBeginning`
* Only `hasEnd`
* Both `hasBeginning` and `hasEnd`

Currently, there's no check regarding the date-time fields.  For example,
the back-end do not check if `hasBeginning` is older than `hasEnd`.

The fields that take a reference (ID) to a record (such as
`resourceInventoriedAs`, `resourceConformsTo`, `atLocation`, and `toLocation`)
checks if the provided record exists.  You can't create an event with invalid
references.

The quantity fields take only positive amounts at the moment.


### Produce Events

`produce` events are used for creating stuff.  This does not only mean something
like harvesting crops, making a wood toy; it can also mean separating a resource
that have quantities of five pieces into five individual pieces (in that case,
you'd `consume` the resource that have five pieces, and `produce` five individual
pieces).

Generally used with `consume`, `work`, `use`, and `cite` events together to
create a meaningful scenario.

There are two things a `produce` event can do:

* creating a new resource
* increasing quantities of an existing resource

The back-end differentiates them by whether the event has
`resourceInventoriedAs` field or not.  If it has, it'll try to increase the
quantities of the resource `resourceInventoriedAs`.

Whether it creates a new resource or just increases the quantities of an existing
resource, the events will require `outputOf`, `resourceConformsTo`, and
`resourceQuantity` to be provided, and that the `provider` and `receiver` are
the same agents.

If it creates a new resource, it'll try to get the fields `name`, `note`,
`trackingIdentifier`, `currentLocation`, and `stage` from
`newInventoriedResource` and put them into the newly-created resource.

If it increases the quantities of an existing resource, it'll just do it, but
these requirements must be met first:

* The `provider` and `receiver` must be the same agent as the
  `primaryAccountable` and `custodian` of the resource `resourceInventoriedAs`.
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` and `onhandQuantity.hasUnit` of the resource
  `resourceInventoriedAs`.
* The `resourceConformsTo` must be same as `conformsTo` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a container or packed resource.


### Raise Events

`raise` events are pretty much require and have the same side-effects as
`produce` events, but they can't have `outputOf` (or `inputOf`).

The semantic meaning of `raise`, hower is different than `produce`.


### Consume Events

`consume` events are used for... consuming stuff.  This does not only mean
something like consuming seeds to plant crops; it can also mean separating a
resource that have quantities of five pieces into five individual pieces (in
that case, you'd `consume` the resource that have five pieces, and `produce` five
individual pieces).

Generally used with `produce`, `work`, `use`, and `cite` events together to
create a meaningful scenario.

The events require `inputOf`, `resourceInventoriedAs`, and `resourceQuantity`
to be provided, and that the `provider` and `receiver` are the same agents.

It'll decrease the quantities of the resource `resourceInventoriedAs`, but these
requirements must be met:

* The `provider` and `receiver` must be the same agent as the
  `primaryAccountable` and `custodian` of the resource `resourceInventoriedAs`.
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` and `onhandQuantity.hasUnit` of the resource
  `resourceInventoriedAs`.
* The `resourceInventoriedAs` can't be a container or packed resource.


### Lower Events

`lower` events are pretty much require and have the same side-effects as
`consume` events, but they can't have `inputOf` (or `outputOf`).

The semantic meaning of `lower`, hower is different than `consume`.


### Use Events

`use` events are used for... using stuff.  The stuff you use are either an
actual resource or its specification.

Generally used with `produce`, `consume`, `work`, and `cite` events together to
create a meaningful scenario.

The events require `inputOf`, `effortQuantity`, and either
`resourceInventoriedAs` or `resourceConformsTo` (they're mutally-exclusive).
Optionally, you can also provide `resourceQuantity`.

If you choose to have `resourceInventoriedAs`, these requirements must be met:

* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` and `onhandQuantity.hasUnit` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a container or packed resource.


### Work Events

`work` events are used for indicating labor power used in a process.  This can
be the "repairing" in a car repairing scenario, "kneading" in a making a pie
scenario.

Generally used with `produce`, `consume`, `use`, and `cite` events together to
create a meaningful scenario.

The events require `inputOf`, `effortQuantity`, and `resourceConformsTo`.


### Cite Events

`cite` events are used for indicating the usage of instructions, blueprints and
the like.  They are used resourced but not consumed (that is, decreasing
quantities).

Generally used with `produce`, `consume`, `use`, and `work` events together to
create a meaningful scenario.

The events require `inputOf`, and `resourceQuantity`, and `resourceConformsTo`
or `resourceInventoriedAs` (they're mutually-exclusive).

If you choose to have `resourceInventoriedAs`, these requirements must be met:

* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` and `onhandQuantity.hasUnit` of the resource
* The `resourceInventoriedAs` can't be a container or packed resource.


### DeliverService Events

`deliverService` events are used for indicating delivered services, such as
transportation of apples, painting the walls of the house.

The events require `inputOf` and/or `outputOf`, and
`resourceConformsTo`.  If both of `inputOf` and `outputOf` are provided, they
must refer to different Processes.


### Pickup and Dropoff Events

`pickup` and `dropoff` events are used in pairs to transport resources from one
location to another.

`pickup` and `dropoff` events are paired through the resource
`resourceInventoriedAs`.  If they both refer to the same resource, they are
paired.  That's the definition of "pair" here.

The `pickup` events require `inputOf`, `resourceQuantity`, and
`resourceInventoriedAs`, and that the `provider` and `receiver` are the same
agents.

The `pickup` events also require that:

* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a packed resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `onhandQuantity.hasUnit` of the resource `resourceInventoriedAs`
* The `onhandQuantity.hasNumericalValue` of the resource is positive
* The `resourceQuantity.hasNumericalValue` of the event must be the same as
  `onhandQuantity.hasNumericalValue` of the resource `resourceInventoriedAs`
* There is no other `pickup` event that refers to the same resource
  `resourceInventoriedAs` in the same process

The `dropoff` events requires `outputOf`, `resourceQuantity`, and
`resourceInventoriedAs`, and that the `provider` and `receiver` are the same
agents.

The `dropoff` events also requires that:

* There is exactly one `pickup` event referring to the same resource
  `resourceInventoriedAs` in the same process.  Due to this, most of the
  `pickup` events requrimenst apply here out of the box
* The `provider` is the same agent as the `provider` of the paired event
* There is no other `dropoff` events that refer to the same resource
  `resourceInventoriedAs` in the same process
* The `resourceQuantity.hasUnit` of the event must be the same as
  the paired `pickup` event's `resourceQuantity.hasUnit`

If `toLocation` is provided, `dropoff` events will set the `currentLocation` of
the resource `resourceInventoriedAs`.  If the resource `resourceInventoriedAs`
is a container, it'll also set the `currentLocation` of all the contained
resources.

I'm thinking to add another validation logic here: until the resource
`resourceInventoriedAs` is `dropoff`'ed, any other event that are not in the
same process won't be able to affect it (as in `consume`, `cite`, `use`,
`transfer`, and so on).


### Accept and Modify Events

`accept` and `modify` events are used in pairs and have the follow
functionalities:

* set a resource's `stage` field
* specify the container resource used for `pack` and `unpack`

`accept` and `modify` events are paired through the resource
`resourceInventoriedAs`.  If they both refer to the same resource, they are
paired.  That's the definition of "pair" here.

The `accept` events require `inputOf`, `resourceQuantity`, and
`resourceInventoriedAs`, and that the `provider` and `receiver` are the same
agents.

The `accept` events also require that:

* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a packed resource.
* There is no other `accept` event that refers to the same resource
  `resourceInventoriedAs` in the same process
* The `resourceQuantity.hasUnit` of the event must be the same as
  `onhandQuantity.hasUnit` of the resource `resourceInventoriedAs`
* There is no `pack` or `unpack` events in the same process
* If the resource `resourceInventoriedAs` is a contanier, the
  `onhandQuantity.hasNumericalValue` of the resource is positive
* If the resource `resourceInventoriedAs` is a container, the
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `onhandQuantity.hasNumericalValue` of the resource

If these requirements above are met, the `onhandQuantity.hasNumericalValue` of
the resource `resourceInventoriedAs` will be decreased by
`resourceQuantity.hasNumericalValue` of the event.

The `modify` events require `outputOf`, `resourceQuantity`, and
`resourceInventoriedAs`, and that the `provider` and `receiver` are the same
agents.

The `modify` events also require that:

* There is exactly one `accept` event referring to the same resource
  `resourceInventoriedAs` in the same process.  Due to this, most of the
  `accept` events requrimenst apply here out of the box
* The `provider` is the same agent as the `provider` of the paired event
* The `resourceQuantity.hasUnit` of the event must be the same as
  the paired `accept` event's `resourceQuantity.hasUnit`
* There is no other `modify` events that refer to the same resource
  `resourceInventoriedAs` in the same process
* The `resourceQuantity.hasNumericalValue` of the event must be the same as
  the paired `accept` event's `resourceQuantity.hasNumericalValue`

If these requirements above are met, the `onhandQuantity.hasNumericalValue` of
the resource `resourceInventoriedAs` will be increased by
`resourceQuantity.hasNumericalValue` of the event, and the resource's `stage`
will be set to the same ProcessesSpecification of the current Process (`basedOn`
field of the Process).  Note that this also includes the `null` value.


### Pack and Unpack Events

`pack` and `unpack` events are *not* used in pairs, even though it kinda sounds
like that.  `pack` events put a resource into a container resource, `unpack`
events take them out.

The `pack` events require `inputOf`, and `resourceInventoriedAs`, and that the
`provider` and `receiver` are the same agents.

The `pack` events also require that:

* There's exactly one `accept` event in the same process.  It requires it
  beforehand so that the back-end can see what container is used with this
* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be an already-packed resource
* There is no `unpack` events in the same process

If these requirements above are met, the `containedIn` of the resource
`resourceInventoriedAs` will be set to `resourceInventoriedAs` of the accept
event in the process.

The `unpack` events require `outputOf`, and `resourceInventoriedAs`, and that the
`provider` and `receiver` are the same agents.

The `unpack` events also require that:

* There's exactly one `accept` event in the same process.  It requires it
  beforehand so that the back-end can see what container is used with this
* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The resource `resourceInventoriedAs` is actually in the container provided by
  the `accept` event
* There is no `pack` events in the same process

If these requirements above are met, the `containedIn` of the resource
`resourceInventoriedAs` will be set to `null`.


### TransferCustody Events

`transferCustody` events transfer the custody ownership, that is, `custodian`
and thus, it only affects `onhandQuantity`.

There are two things a `transferCustody` event can do:

* when only `resourceInventoriedAs` is provided, it'll create a new resource on
  the other end
* when both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided,
  it'll increase the `onhandQuantity` of `toResourceInventoriedAs` while
  decreasing `resourceInventoriedAs`'s

In any case, they require `resourceInventoriedAs`, `resourceQuantity` and,
optionally if you want to "transfer into" another resource,
`toResourceInventoriedAs`.

If only `resourceInventoriedAs` is provided, you need to fulfill these
requirements:

* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a packed resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `onhandQuantity.hasUnit` of the resource `resourceInventoriedAs`
* If the resource `resourceInventoriedAs` is a container, the
  `onhandQuantity.hasNumericalValue` of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `onhandQuantity.hasNumericalValue` of the resource

If these requirements above are met, it'll create a new resource that will:

* have `onhandQuantity.hasUnit` and `onhandQuantity.hasNumericalValue` set from
  `resourceQuantity` of the event
* have `accountingQuantity.hasNumericalValue` set to `0` and
  `accountingQuantity.hasUnit` set to `resourceQuantity.hasUnit` of the event
* have `currentLocation` set to `toLocation` of the event, if it is available
* have all the other fields copied from the resource `resourceInventoriedAs`,
  except for `name`, `note`, `trackingIdentifier` if they are provided by
  `newInventoriedResource` when creating the event

It'll also decrease the `onhandQuantity.hasNumericalValue` of the resourece
`resourceInventoriedAs` by `resourceQuantity.hasNumericalValue` of the event.
And if the resource `resourceInventoriedAs` was a container, the packed resources'
`containedIn` will be set to the newly created resource and `custodian` set to
`receiver` of the event.

If both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided, you
need to fulfill these requirements:

* The `provider` is the same agent as the `custodian` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` and `toResourceInventoriedAs` can't be a packed
  resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `onhandQuantity.hasUnit` of the resource `resourceInventoriedAs` and
  `toResourceInventoriedAs`
* The `resourceInventoriedAs.conformsTo` and
  `toResourceInventoriedAs.conformsTo` must bethe same
* If the resource `resourceInventoriedAs` is a container, the
  `onhandQuantity.hasNumericalValue` of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `onhandQuantity.hasNumericalValue` of the resource

If these requirements above are met, it'll increase the
`onhandQuantity.hasNumericalValue` of the resource `toResourceInventoriedAs`
while decreasing `onhandQuantity.hasNumericalValue` of `resourceInventoriedAs`
by `resourceQuantity.hasNumericalValue` of the event.  And if the resource
`resourceInventoriedAs` was a container, the packed resources' `containedIn`
will be set to `toResourceInventoriedAs` and `custodian` set to `receiver` of
the event.


### TransferAllRights Events

`transferAllRight` events transfer the accounting ownership, that is,
`primaryAccountable` and thus, it only affects `accountingQuantity`.

There are two things a `transferAllRight` event can do:

* when only `resourceInventoriedAs` is provided, it'll create a new resource on
  the other end
* when both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided,
  it'll increase the `accountingQuantity` of `toResourceInventoriedAs` while
  decreasing `resourceInventoriedAs`'s

In any case, they require `resourceInventoriedAs`, `resourceQuantity` and,
optionally if you want to "transfer into" another resource,
`toResourceInventoriedAs`.

If only `resourceInventoriedAs` is provided, you need to fulfill these
requirements:

* The `provider` is the same agent as the `primaryAccountable` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a packed resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` of the resource `resourceInventoriedAs`
* If the resource `resourceInventoriedAs` is a container, the
  `accountingQuantity.hasNumericalValue` of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `accountingQuantity.hasNumericalValue` of the resource

If these requirements above are met, it'll create a new resource that will:

* have `accountingQuantity.hasUnit` and `accountingQuantity.hasNumericalValue`
  set from `resourceQuantity` of the event
* have `onhandQuantity.hasNumericalValue` set to `0` and
  `onhandQuantity.hasUnit` set to `resourceQuantity.hasUnit` of the event
* have all the other fields copied from the resource `resourceInventoriedAs`,
  except for `name`, `note`, `trackingIdentifier` if they are provided by
  `newInventoriedResource` when creating the event

It'll also decrease the `accountingQuantity.hasNumericalValue` of the resourece
`resourceInventoriedAs` by `resourceQuantity.hasNumericalValue` of the event.
And if the resource `resourceInventoriedAs` was a container, the packed resources'
`containedIn` will be set to the newly created resource and `primaryAccountable`
set to `receiver` of the event.

If both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided, you
need to fulfill these requirements:

* The `provider` is the same agent as the `primaryAccountable` of the resource
  `resourceInventoriedAs`
* The `resourceInventoriedAs` and `toResourceInventoriedAs` can't be a packed
  resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity.hasUnit` of the resource `resourceInventoriedAs` and
  `toResourceInventoriedAs`
* The `resourceInventoriedAs.conformsTo` and
  `toResourceInventoriedAs.conformsTo` must bethe same
* If the resource `resourceInventoriedAs` is a container, the
  `accountingQuantity.hasNumericalValue` of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `accountingQuantity.hasNumericalValue` of the resource

If these requirements above are met, it'll increase the
`accountingQuantity.hasNumericalValue` of the resource `toResourceInventoriedAs`
while decreasing `accountingQuantity.hasNumericalValue` of
`resourceInventoriedAs` by `resourceQuantity.hasNumericalValue` of the event.
And if the resource `resourceInventoriedAs` was a container, the packed
resources' `containedIn` will be set to `toResourceInventoriedAs` and
`primaryAccountable` set to `receiver` of the event.


### Transfer Events

`transfer` events transfer the both types of ownership, that is,
`primaryAccountable` and `custodian` and thus, it affects both
`accountingQuantity` and `onhandQuantity`.

There are two things a `transfer` event can do:

* when only `resourceInventoriedAs` is provided, it'll create a new resource on
  the other end
* when both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided,
  it'll increase the `accountingQuantity` and `onhandQuantity` of
  `toResourceInventoriedAs` while decreasing `resourceInventoriedAs`'s

In any case, they require `resourceInventoriedAs`, `resourceQuantity` and,
optionally if you want to "transfer into" another resource,
`toResourceInventoriedAs`.

If only `resourceInventoriedAs` is provided, you need to fulfill these
requirements:

* The `provider` is the same agent as the `primaryAccountable` and `custodian`
  of the resource `resourceInventoriedAs`
* The `resourceInventoriedAs` can't be a packed resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity` and `onhandQuantity.hasUnit` of the resource
  `resourceInventoriedAs`
* If the resource `resourceInventoriedAs` is a container, the
  `accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue`
  of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue`
  of the resource

If these requirements above are met, it'll create a new resource that will:

* have `accountingQuantity.hasUnit`, `accountingQuantity.hasNumericalValue`,
  `onhandQuantity.hasUnit`, and `onhandQuantity.hasNumericalValue` set from
  `resourceQuantity` of the event
* have all the other fields copied from the resource `resourceInventoriedAs`,
  except for `name`, `note`, `trackingIdentifier` if they are provided by
  `newInventoriedResource` when creating the event

It'll also decrease the `accountingQuantity.hasNumericalValue` and
`onhandQuantity.hasNumericalValue` of the resourece `resourceInventoriedAs` by
`resourceQuantity.hasNumericalValue` of the event.
And if the resource `resourceInventoriedAs` was a container, the packed resources'
`containedIn` will be set to the newly created resource, and `primaryAccountable`
and `custodian` set to `receiver` of the event.

If both `resourceInventoriedAs` and `toResourceInventoriedAs` are provided, you
need to fulfill these requirements:

* The `provider` is the same agent as the `primaryAccountable` and `custodian`
  of the resource `resourceInventoriedAs`
* The `resourceInventoriedAs` and `toResourceInventoriedAs` can't be a packed
  resource
* The `resourceQuantity.hasUnit` of the event must be the same as
  `accountingQuantity` and `onhandQuantity.hasUnit` of the resource
  `resourceInventoriedAs` and `toResourceInventoriedAs`
* The `resourceInventoriedAs.conformsTo` and
  `toResourceInventoriedAs.conformsTo` must bethe same
* If the resource `resourceInventoriedAs` is a container, the
  `accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue`
  of the resource must be postitive
* If the resource `resourceInventoriedAs` is a container,
  `resourceQuantity.hasNumericalValue` of the event must be the same as
  `accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue`
  of the resource

If these requirements above are met, it'll increase the
`accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue` of
the resource `toResourceInventoriedAs` while decreasing
`accountingQuantity.hasNumericalValue` and `onhandQuantity.hasNumericalValue` of
`resourceInventoriedAs` by `resourceQuantity.hasNumericalValue` of the event.
And if the resource `resourceInventoriedAs` was a container, the packed
resources' `containedIn` will be set to `toResourceInventoriedAs`, and
`primaryAccountable` and `custodian` set to `receiver` of the event.


### Move Events

`move` events are used for internal dividing and such.  When companed to
`transfer`, it is similar to what `produce` is to `raise` and what `consume` is
to `lower`

The only differenece between `move` and `transfer` in the back-end is that
`move` requires both the `provider` and `receiver` be the same person.


## Examples


### Produce Examples
Harvesting apples from a tree farm.

Give:
```
mutation {
  createEconomicEvent(
    event: {
      action: "produce"
      provider: "01FWN12XX7TJX1AFF5KA4WPNN9" # bob
      receiver: "01FWN12XX7TJX1AFF5KA4WPNN9" # bob
      outputOf: "01FWN136SPDMKWWF23SWQZRM5F" # harvesting apples process
      resourceConformsTo: "01FWN136Y4ZZ7K9F314HQ7MKRG" # apple
      resourceQuantity: {
        hasNumericalValue: 50
        hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
      }
      atLocation: "01FWN136ZAPQ5ENBF3FZ79935D" # bob's farm
      hasPointInTime: "2022-01-02T03:04:05Z"
    }
    newInventoriedResource: {
      name: "bob's apples"
      note: "bob's delish apples"
      trackingIdentifier: "lot 123"
      currentLocation: "01FWN136ZAPQ5ENBF3FZ79935D" # bob's farm
      stage: "01FWN136X183DM43CTWXESNWAB" # fresh
    }
  ) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      outputOf {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
    economicResource { # this is the newly-created resource
      id
      name
      note
      trackingIdentifier
      stage {id}
      currentLocation {id}
      conformsTo {id}
      primaryAccountable {id}
      custodian {id}
      accountingQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      onhandQuantity {
        hasNumericalValue
        hasUnit {id}
      }
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN16MMRPWEWCWHGNNH9TCTK",
        "action": {"id": "produce"},
        "provider": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "receiver": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "outputOf": {"id": "01FWN136SPDMKWWF23SWQZRM5F"}, # harvesting apples process
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 50,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "atLocation": {"id": "01FWN136ZAPQ5ENBF3FZ79935D"}, # bob's farm
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      },
      "economicResource": {
        "id": "01FWN16MMVVVWEWTMC6Z5PMCM0",
        "name": "bob's apples",
        "note": "bob's delish apples",
        "trackingIdentifier": "lot 123",
        "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
        "currentLocation": {"id": "01FWN136ZAPQ5ENBF3FZ79935D"}, # bob's farm
        "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "primaryAccountable": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "custodian": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "accountingQuantity": {
          "hasNumericalValue": 50,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "onhandQuantity": {
          "hasNumericalValue": 50,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        }
      }
    }
  }
}
```

Harvesting apples, but using the existing apple resource (created above).

Give:
```
mutation {
  createEconomicEvent(event: {
      action: "produce"
      provider: "01FWN12XX7TJX1AFF5KA4WPNN9" # bob
      receiver: "01FWN12XX7TJX1AFF5KA4WPNN9" # bob
      outputOf: "01FWN136SPDMKWWF23SWQZRM5F" # harvesting apples process
      resourceConformsTo: "01FWN136Y4ZZ7K9F314HQ7MKRG" # apple
      resourceQuantity: {
        hasNumericalValue: 15
        hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
      }
      resourceInventoriedAs: "01FWN16MMVVVWEWTMC6Z5PMCM0" # resource "bob's apples"
      atLocation: "01FWN136ZAPQ5ENBF3FZ79935D" # bob's farm
      hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      outputOf {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs { # this is the already-existing resource "bob's apples"
        id
        name
        note
        trackingIdentifier
        stage {id}
        currentLocation {id}
        conformsTo {id}
        primaryAccountable {id}
        custodian {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN2Z7XNACJBT2K4TR9EM40W",
        "action": {"id": "produce"},
        "provider": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "receiver": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "outputOf": {"id": "01FWN136SPDMKWWF23SWQZRM5F"}, # harvesting apples process
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 15,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "atLocation": {"id": "01FWN136ZAPQ5ENBF3FZ79935D"}, # bob's farm
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      },
      "economicResource": {
        "id": "01FWN16MMVVVWEWTMC6Z5PMCM0",
        "name": "bob's apples",
        "note": "bob's delish apples",
        "trackingIdentifier": "lot 123",
        "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
        "currentLocation": {"id": "01FWN136ZAPQ5ENBF3FZ79935D"}, # bob's farm
        "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "primaryAccountable": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "custodian": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob
        "accountingQuantity": {
          "hasNumericalValue": 65,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "onhandQuantity": {
          "hasNumericalValue": 65,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        }
      }
    }
  }
}
```


### Raise Examples
Suppose a person joined to the instance at a later time.  But they already have
some resources they want to import.  You can use `raise` events for that.

Give:
```
mutation {
  createEconomicEvent(
    event: {
      action: "raise"
      provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
      receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
      resourceConformsTo: "01FWN136Y4ZZ7K9F314HQ7MKRG" # apple
      resourceQuantity: {
        hasNumericalValue: 30
        hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
      }
      atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
      hasPointInTime: "2022-01-02T03:04:05Z"
    }
    newInventoriedResource: {
      name: "alice's apples"
      note: "alice's delish apples"
      trackingIdentifier: "lot 123"
      currentLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
      stage: "01FWN136X183DM43CTWXESNWAB" # fresh
    }
  ) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
    economicResource { # this is the newly-created resource
      id
      name
      note
      trackingIdentifier
      stage {id}
      currentLocation {id}
      conformsTo {id}
      primaryAccountable {id}
      custodian {id}
      accountingQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      onhandQuantity {
        hasNumericalValue
        hasUnit {id}
      }
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN3YAT32CGRFJG827XWTSWY",
        "action": {"id": "raise"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 30,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      },
      "economicResource": {
        "id": "01FWN3ZY2Z8ZJ071YXJ315KC2W",
        "name": "alice's apples",
        "note": "alice's delish apples",
        "trackingIdentifier": "lot 123",
        "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
        "currentLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "primaryAccountable": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "custodian": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "accountingQuantity": {
          "hasNumericalValue": 30,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "onhandQuantity": {
          "hasNumericalValue": 30,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        }
      }
    }
  }
}
```

Found more apples?  Add them to the stack!

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "raise"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    resourceConformsTo: "01FWN136Y4ZZ7K9F314HQ7MKRG" # apple
    resourceQuantity: {
      hasNumericalValue: 15
      hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
    }
    resourceInventoriedAs: "01FWN3ZY2Z8ZJ071YXJ315KC2W" # resource "alice's apples"
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs { # this is the already-existing resource "bob's apples"
        id
        name
        note
        trackingIdentifier
        stage {id}
        currentLocation {id}
        conformsTo {id}
        primaryAccountable {id}
        custodian {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN3ZY2Z8ZJ071YXJ315KC2W",
        "action": {"id": "raise"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 15,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "resourceInventoriedAs": {
          "id": "01FWN3ZY2Z8ZJ071YXJ315KC2W",
          "name": "alice's apples",
          "note": "alice's delish apples",
          "trackingIdentifier": "lot 123",
          "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
          "currentLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
          "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
          "primaryAccountable": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "custodian": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "accountingQuantity": {
            "hasNumericalValue": 45,
            "hasUnit": {"id": "01FW15136S5VPCCR3B3TGYDYEY9"} # kilogram
          },
          "onhandQuantity": {
            "hasNumericalValue": 45,
            "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
          }
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```


### Consume Examples

Consume apples for making apple juice.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "consume"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWN5SVCHH662KD10E73M221J" # process "making apple juice"
    resourceInventoriedAs: "01FWN3ZY2Z8ZJ071YXJ315KC2W" # resource "alice's apples" 45kg
    resourceQuantity: {
      hasNumericalValue: 20
      hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
    }
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      inputOf {id}
      resourceInventoriedAs {
        id
        name
        note
        trackingIdentifier
        stage {id}
        currentLocation {id}
        conformsTo {id}
        primaryAccountable {id}
        custodian {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
      }
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN6ABS0RCKEVC636N8TY58D",
        "action": {"id": "consume"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWN5SVCHH662KD10E73M221J"}, # process "making apple juice"
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 20,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "resourceInventoriedAs": {
          "id": "01FWN3ZY2Z8ZJ071YXJ315KC2W",
          "name": "alice's apples",
          "note": "alice's delish apples",
          "trackingIdentifier": "lot 123",
          "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
          "currentLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
          "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
          "primaryAccountable": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "custodian": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "accountingQuantity": {
            "hasNumericalValue": 25, # = 45 - 15
            "hasUnit": {"id": "01FW15136S5VPCCR3B3TGYDYEY9"} # kilogram
          },
          "onhandQuantity": {
            "hasNumericalValue": 25, # = 45 - 15
            "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
          }
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```

### Lower Examples

Oh, did you import 5kg of apples accidentally?  We can `lower` it!

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "lower"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    resourceInventoriedAs: "01FWN3ZY2Z8ZJ071YXJ315KC2W" # resource "alice's apples" 20kg
    resourceQuantity: {
      hasNumericalValue: 5
      hasUnit: "01FWN136S5VPCCR3B3TGYDYEY9" # kilogram
    }
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      resourceInventoriedAs {
        id
        name
        note
        trackingIdentifier
        stage {id}
        currentLocation {id}
        conformsTo {id}
        primaryAccountable {id}
        custodian {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
      }
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN6ABS0RCKEVC636N8TY58D",
        "action": {"id": "lower"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "resourceConformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
        "resourceQuantity": {
          "hasNumericalValue": 5,
          "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
        },
        "resourceInventoriedAs": {
          "id": "01FWN3ZY2Z8ZJ071YXJ315KC2W",
          "name": "alice's apples",
          "note": "alice's delish apples",
          "trackingIdentifier": "lot 123",
          "stage": {"id": "01FWN136X183DM43CTWXESNWAB"}, # fresh
          "currentLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
          "conformsTo": {"id": "01FWN136Y4ZZ7K9F314HQ7MKRG"}, # apple
          "primaryAccountable": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "custodian": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
          "accountingQuantity": {
            "hasNumericalValue": 15, # = 20 - 5
            "hasUnit": {"id": "01FW15136S5VPCCR3B3TGYDYEY9"} # kilogram
          },
          "onhandQuantity": {
            "hasNumericalValue": 15, # = 20 - 5
            "hasUnit": {"id": "01FWN136S5VPCCR3B3TGYDYEY9"} # kilogram
          }
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```


### Use Examples

Suppose you want to make some apple juice out of... apples.  You would `consume`
some apple resources and `produce` some apple juice resources, but this story
doesn't sound quite right.  If you want to record how you did get the juice, you
could use a `use` event, specifying that you used a juicer.

The below example demonstates that we used a juicer machine for 2 hours.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "use"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWN9E7MD5JKJE52EMP5MHYT3" # process "making apple juice"
    resourceInventoriedAs: "01FWN9A23V1Y1XRJPZ5CG2BDYW" # the juicer
    resourceQuantity: {
      hasNumericalValue: 1
      hasUnit: "01FWN9828J8M6NB95C0GV0Z324" # one/each/pcs
    }
    effortQuantity: {
      hasNumericalValue: 2
      hasUnit: "01FWN96JV5KG2N91Q3FSZRZZQ3" # hour
    }
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      inputOf {id}
      resourceInventoriedAs {
        id
        name
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
      }
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      effortQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWN9W5Y9JY6ZFTZ6518SF6PP",
        "action": {"id": "use"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWN9E7MD5JKJE52EMP5MHYT3"}, # process "making apple juice"
        "resourceInventoriedAs": {
          "id": "01FWN9A23V1Y1XRJPZ5CG2BDYW",
          "name": "the juicer machine",
          "accountingQuantity": {
            "hasNumericalValue": 1,
            "hasUnit": {"id": "01FWN9828J8M6NB95C0GV0Z324"} # one/each/pcs
          },
          "onhandQuantity": {
            "hasNumericalValue": 1,
            "hasUnit": {"id": "01FWN9828J8M6NB95C0GV0Z324"} # one/each/pcs
          }
        },
        "resourceQuantity": {
          "hasNumericalValue": 1,
          "hasUnit": {"id": "01FWN9828J8M6NB95C0GV0Z324"} # one/each/pcs
        },
        "effortQuantity": {
          "hasNumericalValue": 2,
          "hasUnit": {"id": "01FWN96JV5KG2N91Q3FSZRZZQ3"} # hour
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```

You can also choose to not use `resourceQuantity` or `resourceInventoriedAs` at
all.  But if you choose to not use `resourceInventoriedAs`, you must provide a
ResourceSpecification in the field `resourceConformsTo`.

This would mean that we used a machine for 2 hours, but we didn't want to use an
actual resource for it and didn't want to provide how many of them we used.
This is a valid usage of `use` events.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "use"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWN9E7MD5JKJE52EMP5MHYT3" # process "making apple juice"
    resourceConformsTo: "01FWNA5WDM5FPJYPQ3BTGMFTQ5" # resource spec "juicer machine"
    effortQuantity: {
      hasNumericalValue: 2
      hasUnit: "01FWN96JV5KG2N91Q3FSZRZZQ3" # hour
    }
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      inputOf {id}
      resourceConformsTo {id}
      effortQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWNA7DETHVJ2C97AQWK55Y8B",
        "action": {"id": "use"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWN9E7MD5JKJE52EMP5MHYT3"}, # process "making apple juice"
        "resourceConformsTo": {"id": "01FWN9A23V1Y1XRJPZ5CG2BDYW"},
        "effortQuantity": {
          "hasNumericalValue": 2,
          "hasUnit": {"id": "01FWN96JV5KG2N91Q3FSZRZZQ3"} # hour
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```


### Work Examples

`works` events are used when you want to specify what kind of work you put in a
process.  Suppose you are making some apple pies, and you are kneading the dough
for the crust; you'd put "kneading the dough" as a work event to the proccess.

There's a small catch, though: as the term "resource", thus its "specification",
is broad in the Valueflows vocabulary, you are required to provide what kind of
work you do to the field `resourceConformsTo`, that is, there's no such field
as `effortConformsTo` and a type as `EffortSpecification`.  Such work would be
"kneading" in a "making apple pies" scenario.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "work"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWTXNRFVYPR98WQGPVB69DW8" # process "making apple pies"
    resourceConformsTo: "01FWTWNTZEWYKAT0S45809QMFN" # resource spec "kneading"
    effortQuantity: {
      hasNumericalValue: 2
      hasUnit: "01FWN96JV5KG2N91Q3FSZRZZQ3" # hour
    }
    atLocation: "01FWN3VH3H8T4KHN8XC7FJ32V3" # alice's kitchen
    hasPointInTime: "2022-01-02T03:04:05Z
  }) {
    economicEvent {
      id
      provider {id}
      receiver {id}
      inputOf {id}
      resourceInventoriedAs {id}
      effortQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWTXN8ZY01XXNG9QK47PEKNH",
        "action": {"id": "work"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWTXNRFVYPR98WQGPVB69DW8"}, # process "making apple pies"
        "resourceConformsTo": {"id": "01FWTWNTZEWYKAT0S45809QMFN"}, # resource spec "kneading"
        "effortQuantity": {
          "hasNumericalValue": 2,
          "hasUnit": {"id": "01FWN96JV5KG2N91Q3FSZRZZQ3"}, # hour
        },
        "atLocation": {"id": "01FWN3VH3H8T4KHN8XC7FJ32V3"}, # alice's kitchen
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```


### Cite Examples

Suppose you are some sort of instruction paper, design files, blueprints (all
can be digital as well) to produce something.  You record the history of that
with `cite` events.  They cosume the cited resource.  They're there because they
help us to create a more meaningful history.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "cite"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWPA0H6YB1NDP2X1HNCXFQN9" # process "creating flags"
    resourceInventoriedAs: "01FWPA7HXMA25AGA3VXXR0540K" # resource "flag design"
    resourceQuantity: {
      hasNumericalValue: 1
      hasUnit: "01FWN9828J8M6NB95C0GV0Z324" # one/each/pcs
    }
    atLocation: "01FWPAG1YVBXXPTQNSCFG48RTY" # alice's workshop
    hasPointInTime: "2022-01-02T03:04:05Z
  }) {
    economicEvent {
      id
      provider {id}
      receiver {id}
      inputOf {id}
      resourceInventoriedAs {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWPAE4JC2P039G4B93D0AS4Q",
        "action": {"id": "cite"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWPA0H6YB1NDP2X1HNCXFQN9"}, # process "creating flags"
        "resourceInventoriedAs": {"id": "01FWPA7HXMA25AGA3VXXR0540K"}, # resource "flag design"
        "resourceQuantity": {
          "hasNumericalValue": 1,
          "hasUnit": {"id": "01FWN9828J8M6NB95C0GV0Z324"}, # one/each/pcs
        },
        "atLocation": {"id": "01FWPAG1YVBXXPTQNSCFG48RTY"}, # alice's workshop
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```

With `cite` events, you may wish to just use a ResourceSpecification instead of
an Economicresource.  But, you must provide the quantity nonetheless.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "cite"
    provider: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice
    inputOf: "01FWPA0H6YB1NDP2X1HNCXFQN9" # process "creating flags"
    resourceConformsTo: "01FWPAN3ST2FE431DSBQTCMBN9" # resource spec "flag design"
    resourceQuantity: {
      hasNumericalValue: 1
      hasUnit: "01FWN9828J8M6NB95C0GV0Z324" # one/each/pcs
    }
    atLocation: "01FWPAG1YVBXXPTQNSCFG48RTY" # alice's workshop
    hasPointInTime: "2022-01-02T03:04:05Z
  }) {
    economicEvent {
      id
      provider {id}
      receiver {id}
      inputOf {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWPAE4JC2P039G4B93D0AS4Q",
        "action": {"id": "cite"},
        "provider": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice
        "inputOf": {"id": "01FWPA0H6YB1NDP2X1HNCXFQN9"}, # process "creating flags"
        "resourceConformsTo": {"id": "01FWPAN3ST2FE431DSBQTCMBN9"} # resource spec "flag design"
        "resourceQuantity": {
          "hasNumericalValue": 1,
          "hasUnit": {"id": "01FWN9828J8M6NB95C0GV0Z324"}, # one/each/pcs
        },
        "atLocation": {"id": "01FWPAG1YVBXXPTQNSCFG48RTY"}, # alice's workshop
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```


### DeliverService Examples

When you want to indicate the services used in a process, you use
`deliverService` events.

Painting a house, transporting a pizza, and dry-cleaning clothes are examples of
services.

Similar to `work` events, `resourceConformsTo` refer to the type of service.

Give:
```
mutation {
  createEconomicEvent(event: {
    action: "deliverService"
    provider: "01FWN12XX7TJX1AFF5KA4WPNN9" # bob the painter
    receiver: "01FWN3QA3Q2G0JNYHBCCBEN76H" # alice the house owner
    outputOf: "01FWV0BXSCMRWHRCFCQ82JM2S3" # process "painting alice's house"
    resourceConformsTo: "01FWV0G7X0H03BQKPV0W8Q32EA" # resource spec "painting"
    atLocation: "01FWV0REX2G4VHRRBH5QSWD7N8" # alice's house
    hasPointInTime: "2022-01-02T03:04:05Z"
  }) {
    economicEvent {
      id
      provider {id}
      receiver {id}
      outputOf {id}
      resourceConformsTo {id}
      atLocation {id}
      hasPointInTime
    }
  }
}
```

Get:
```
{
  "data": {
    "createEconomicEvent": {
      "economicEvent": {
        "id: "01FWV0N1FE320H75Q8RYVAFTR4",
        "action": {"id": "deliverService"},
        "provider": {"id": "01FWN12XX7TJX1AFF5KA4WPNN9"}, # bob the painter
        "receiver": {"id": "01FWN3QA3Q2G0JNYHBCCBEN76H"}, # alice the house owner
        "outputOf": {"id": "01FWPA0H6YB1NDP2X1HNCXFQN9"}, # process "painting alice's house"
        "resourceConformsTo": {"id": "01FWV0G7X0H03BQKPV0W8Q32EA"} # resource spec "painting"
        "atLocation": {"id": "01FWV0REX2G4VHRRBH5QSWD7N8"}, # alice's workshop
        "hasPointInTime": "2022-01-02T03:04:05.000000Z"
      }
    }
  }
}
```

# GraphQL Documents


## Economic Events

All the events require `action`, `provider`, `receiver` fields along with one of these datetime combinations (no particular validation regarding the datetime fields is performed, such as wether `hasBeginning` is actually older or equal to than `hasEnd`):

* only `hasPointInTime`
* only `hasBeginning`
* only `hasEnd`
* both `hasBeginning` and `hasEnd`

The rest of the sections will asume you are aware of this information.


### Produce Events

Produce events require `outputOf`, `resourceConformsTo`, `resourceQuantity`,
and `newInventoriedResource.name`.  You can provide the soon-to-be-created
resource's `name`, `note`, `trackingIdentifier` through
`newInventoriedResource`.  Here is an example document that uses variables:

```
mutation (
  $outputOf: ID!
  $provider: ID!
  $receiver: ID!
  $resourceConformsTo: ID!
  $resourceQuantity: IMeasure!
  $newInventoriedResource: EconomicResourceCreateParams!
  $hasPointInTime: DateTime
  $hasBeginning: DateTime
  $hasEnd: DateTime
) {
  createEconomicEvent(
    event: {
      action: "produce"
      outputOf: $outputOf
      provider: $provider
      receiver: $receiver
      resourceConformsTo: $resourceConformsTo
      resourceQuantity: $resourceQuantity
      hasPointInTime: $hasPointInTime
      hasBeginning: $hasBeginning
      hasEnd: $hasEnd
    }
    newInventoriedResource: $newInventoriedResource
  ) {
    economicEvent {
      id
      action {id}
      outputOf {id}
      provider {id}
      receiver {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs {
        id
        name
        note
        primaryAccountable {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        conformsTo {id}
      }
      hasPointInTime
      hasEnd
      hasBeginning
    }
  }
}
```

and the example variables:

```
{
  "outputOf": "01G2Q2AT2PHQD56N9RFX3A240J",
  "provider": "01FZFE8E43ANRY360J1E98PJ0Z",
  "receiver": "01FZFE8E43ANRY360J1E98PJ0Z",
  "resourceConformsTo": "01FTB03K54ZF38FHEKGVHTWGY8",
  "resourceQuantity": {
    "hasNumericalValue": 10.0,
    "hasUnit":  "01FTB06BQ64MSS7XSB3QMSW83R"
  },
  "newInventoriedResource": {
    "name":  "some name",
    "note": "some note"
  },
  "hasEnd": "2022-01-02T03:04:05Z"
}
```


### Consume Events

Consume events require `inputOf`, `resourceInventoriedAs`, and
`resourceQuantity` fields.  Here is an example document that uses variables:

```
mutation (
  $inputOf: ID!
  $provider: ID!
  $receiver: ID!
  $resourceInventoriedAs: ID!
  $resourceQuantity: IMeasure!
  $hasPointInTime: DateTime
  $hasBeginning: DateTime
  $hasEnd: DateTime
) {
  createEconomicEvent(event: {
     action: "consume"
     inputOf: $inputOf
     provider: $provider
     receiver: $receiver
     resourceInventoriedAs: $resourceInventoriedAs
     resourceQuantity: $resourceQuantity
     hasPointInTime: $hasPointInTime
     hasBeginning: $hasBeginning
     hasEnd: $hasEnd
  }) {
    economicEvent {
      id
      action {id}
      inputOf {id}
      provider {id}
      receiver {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs {
        id
        name
        note
        primaryAccountable {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        conformsTo {id}
      }
      hasPointInTime
      hasEnd
      hasBeginning
    }
  }
}
```

and the example variables:

```
{
  "inputOf": "01G2Q2AT2PHQD56N9RFX3A240J",
  "provider": "01FZFE8E43ANRY360J1E98PJ0Z",
  "receiver": "01FZFE8E43ANRY360J1E98PJ0Z",
  "resourceInventoriedAs": "01FTB03K54ZF38FHEKGVHTWGY8",
  "resourceQuantity": {
    "hasNumericalValue": 10.0,
    "hasUnit":  "01FTB06BQ64MSS7XSB3QMSW83R"
  },
  "hasPointInTime": "2022-01-02T03:04:05Z"
}
```


### Raise Events

Raise events are almost identical to produce events, execept for their semantic
meaning, and the fact that they don't require `outputOf` to be provided (that's
related to the semantic meaning).  Here is an example document that uses
variables:

```
mutation (
  $provider: ID!
  $receiver: ID!
  $resourceConformsTo: ID!
  $resourceQuantity: IMeasure!
  $newInventoriedResource: EconomicResourceCreateParams!
  $hasPointInTime: DateTime
  $hasBeginning: DateTime
  $hasEnd: DateTime
) {
  createEconomicEvent(
    event: {
      action: "raise"
      provider: $provider
      receiver: $receiver
      resourceConformsTo: $resourceConformsTo
      resourceQuantity: $resourceQuantity
      hasPointInTime: $hasPointInTime
      hasBeginning: $hasBeginning
      hasEnd: $hasEnd
    }
    newInventoriedResource: $newInventoriedResource
  ) {
    economicEvent {
      id
      action {id}
      provider {id}
      receiver {id}
      resourceConformsTo {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs {
        id
        name
        note
        primaryAccountable {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        conformsTo {id}
      }
      hasPointInTime
      hasEnd
      hasBeginning
    }
  }
}
```

and the example variables:

```
{
  "provider": "01FZFE8E43ANRY360J1E98PJ0Z",
  "receiver": "01FZFE8E43ANRY360J1E98PJ0Z",
  "resourceConformsTo": "01FTB03K54ZF38FHEKGVHTWGY8",
  "resourceQuantity": {
    "hasNumericalValue": 10.0,
    "hasUnit":  "01FTB06BQ64MSS7XSB3QMSW83R"
  },
  "newInventoriedResource": {
    "name":  "some name",
    "note": "some note"
  },
  "hasBeginning": "2022-01-02T03:04:05Z"
}
```


### Lower Events

Raise events are almost identical to consume events, execept for their semantic
meaning, and the fact that they don't require `inputOf` to be provided (that's
related to the semantic meaning).  Here is an example document that uses
variables:

```
mutation (
  $provider: ID!
  $receiver: ID!
  $resourceInventoriedAs: ID!
  $resourceQuantity: IMeasure!
  $hasPointInTime: DateTime
  $hasBeginning: DateTime
  $hasEnd: DateTime
) {
  createEconomicEvent(event: {
     action: "lower"
     provider: $provider
     receiver: $receiver
     resourceInventoriedAs: $resourceInventoriedAs
     resourceQuantity: $resourceQuantity
     hasPointInTime: $hasPointInTime
     hasBeginning: $hasBeginning
     hasEnd: $hasEnd
  }) {
    economicEvent {
      id
      action {id}
      inputOf {id}
      provider {id}
      receiver {id}
      resourceQuantity {
        hasNumericalValue
        hasUnit {id}
      }
      resourceInventoriedAs {
        id
        name
        note
        primaryAccountable {id}
        accountingQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        onhandQuantity {
          hasNumericalValue
          hasUnit {id}
        }
        conformsTo {id}
      }
      hasPointInTime
      hasEnd
      hasBeginning
    }
  }
}
```

and the example variables:

```
{
  "provider": "01FZFE8E43ANRY360J1E98PJ0Z",
  "receiver": "01FZFE8E43ANRY360J1E98PJ0Z",
  "resourceInventoriedAs": "01FTB03K54ZF38FHEKGVHTWGY8",
  "resourceQuantity": {
    "hasNumericalValue": 10.0,
    "hasUnit":  "01FTB06BQ64MSS7XSB3QMSW83R"
  },
  "hasBeginning": "2022-01-02T03:04:05Z",
  "hasEnd": "2022-01-02T03:04:05Z"
}
```
