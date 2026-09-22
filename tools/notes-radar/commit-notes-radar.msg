Add notes radar to Song Select chart card

Replace the textual tech annotation (XO 5, FS 11, ...) with a six-axis
radar: STREAM plus the five tech categories. Each tech axis is read as a
share of the chart's own note count, so neither the chart's length nor
the music rate moves the shape, and two charts can be compared by
silhouette rather than only against themselves.

Every axis draws at no less than a base radius, because a chart whose
only strong axis is STREAM otherwise renders as a needle with no area.
The trade is deliberate: a zero axis is no longer distinguishable from a
very low one, and Value keeps the honest number for anyone who needs it.

Reorganise the single-player card below the density graph into a note
count column on the left and the radar to its right. The two-player card
keeps its previous arrangement; 152 units of height has no room for a
six-row column.

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01Tbp1kyopqMgrD4yqqi6auL
