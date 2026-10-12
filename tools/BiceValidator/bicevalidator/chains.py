"""Which event fires which, and which events can ever happen.

An event happens in one of two ways: **the game fires it on its own**, when it has a
`trigger` and is not `is_triggered_only = yes`, or **something fires it** -
`country_event = <id>` or `province_event = <id>` in an event, a decision, an entry of
`common/on_actions.txt` or a block of another file of `common/` (a casus belli's
`on_completion`, a covert operation). So an event that is fired only by events that never
happen does not happen either, however many of them there are.

Reachability is all this says. Whether a trigger can ever be true, whether a decision's
`potential` ever holds and whether a `random` ever rolls are left alone, so an event
called reachable here may still never happen in play - but one called unreachable cannot.
Firing an event also re-tests that event's own trigger (reversing/findings/
FINDINGS-effects.md, "`country_event` - it re-tests the target event's own trigger"), which
is again something only play decides.
"""

from collections import defaultdict


class Chains:
    def __init__(self, events, fires):
        """\\p events: id -> [index.Event]; \\p fires: id -> [index.Site], each with its
        source."""
        self.events = events
        self.fires = fires
        self.fired_by_event = defaultdict(list)     # source event id -> [(target, Site)]
        self.outside = defaultdict(list)            # source key -> [(target, Site)]
        for target, sites in fires.items():
            for site in sites:
                source = site.source
                if source is not None and source.kind == "event":
                    self.fired_by_event[source.name].append((target, site))
                elif source is not None:
                    self.outside[(source.kind, source.name, source.file)].append((target, site))
        self.live = self._reach()

    def _reach(self):
        """Every event id that can happen: those the game fires on its own and those
        fired from outside an event, then whatever those fire, and so on."""
        live = set()
        queue = [ident for ident, found in self.events.items()
                 if any(e.fires_itself for e in found)]
        queue += [target for sites in self.outside.values() for target, _ in sites]
        while queue:
            ident = queue.pop()
            if ident in live:
                continue
            live.add(ident)
            queue += [target for target, _ in self.fired_by_event.get(ident, ())]
        return live

    def can_happen(self, ident):
        return ident in self.live

    def fired_from(self, ident):
        """The Sites that fire event \\p ident."""
        return self.fires.get(ident, [])

    def fires_from(self, kind, name, file=None):
        """(target id, Site) of every event fired from the event, decision, on_actions
        entry or block \\p name."""
        if kind == "event":
            return self.fired_by_event.get(name, [])
        return [pair for (k, n, f), sites in self.outside.items()
                if k == kind and n == name and (file is None or f == file) for pair in sites]

    def dead(self):
        """(event, why, the events that fire it) for every event that can never happen:
        why is "unfired" when nothing fires it, and "dead chain" when only events that
        never happen do."""
        out = []
        for ident, found in sorted(self.events.items(), key=lambda item: _number(item[0])):
            if ident in self.live:
                continue
            for event in found:
                if not event.triggered_only:
                    continue    # BV108 is the code check's: no trigger, and not triggered only
                sources = sorted({s.source.name for s in self.fired_from(ident)
                                  if s.source is not None}, key=_number)
                out.append((event, "dead chain" if sources else "unfired", sources))
        return out

    def path_to(self, ident):
        """The shortest chain of event ids that leads to \\p ident from something that
        happens on its own - an event that fires itself, a decision, on_actions - first
        that something as a Source or an event id, then each event in turn, ending with
        \\p ident; or [] if nothing leads there."""
        if ident not in self.live:
            return []
        starts = {}
        for ident_, found in self.events.items():
            if any(e.fires_itself for e in found):
                starts.setdefault(ident_, [ident_])
        for sites in self.outside.values():
            for target, site in sites:
                starts.setdefault(target, [site.source, target])
        seen = dict(starts)
        frontier = list(starts)
        while frontier:
            if ident in seen:
                return seen[ident]
            following = []
            for current in frontier:
                for target, _ in self.fired_by_event.get(current, ()):
                    if target not in seen:
                        seen[target] = seen[current] + [target]
                        following.append(target)
            frontier = following
        return seen.get(ident, [])


def _number(ident):
    return (0, int(ident), "") if ident.isdigit() else (1, 0, ident)
