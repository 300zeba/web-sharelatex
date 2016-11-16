define [
	"base"
], (App) ->
	App.directive "reviewPanelSorted", ($timeout) ->
		return  {
			link: (scope, element, attrs) ->
				TOOLBAR_HEIGHT = 28
				BOX_PADDING = 12
				INDICATOR_PADDING = 4
				
				previous_focused_entry_index = 0
				
				layout = () ->
					sl_console.log "LAYOUT"
					if scope.ui.reviewPanelOpen
						PADDING = BOX_PADDING
					else
						PADDING = INDICATOR_PADDING
					
					entries = []
					for el in element.find(".rp-entry-wrapper")
						entry = {
							$indicator_el: $(el).find(".rp-entry-indicator")
							$box_el: $(el).find(".rp-entry")
							$callout_el: $(el).find(".rp-entry-callout")
							scope: angular.element(el).scope()
						}
						if scope.ui.reviewPanelOpen
							entry.$layout_el = entry.$box_el
						else
							entry.$layout_el = entry.$indicator_el
						entries.push entry
					entries.sort (a,b) -> a.scope.entry.offset - b.scope.entry.offset
					
					return if entries.length == 0
					
					focused_entry_index = Math.min(previous_focused_entry_index, entries.length - 1)
					for entry, i in entries
						if entry.scope.entry.focused
							focused_entry_index = i
							break
					entries_after = entries.slice(focused_entry_index + 1)
					entries_before = entries.slice(0, focused_entry_index)
					focused_entry = entries[focused_entry_index]
					previous_focused_entry_index = focused_entry_index
					
					sl_console.log "focused_entry_index", focused_entry_index
					
					line_height = 15
					
					# Put the focused entry exactly where it wants to be
					focused_entry_top = Math.max(TOOLBAR_HEIGHT, focused_entry.scope.entry.screenPos.y)
					focused_entry.$box_el.css(top: focused_entry_top)
					focused_entry.$indicator_el.css(top: focused_entry_top)
					focused_entry.$callout_el.css(top: focused_entry_top + line_height, height: 0)
					
					previousBottom = focused_entry_top + focused_entry.$layout_el.height()
					for entry in entries_after
						original_top = entry.scope.entry.screenPos.y
						height = entry.$layout_el.height()
						top = Math.max(original_top, previousBottom + PADDING)
						previousBottom = top + height
						entry.$box_el.css(top: top)
						entry.$indicator_el.css(top: top)
						entry.$callout_el.removeClass("rp-entry-callout-inverted")
						entry.$callout_el.css(top: original_top + line_height, height: top - original_top)
						sl_console.log "ENTRY", {entry: entry.scope.entry, top}
					
					previousTop = focused_entry_top
					entries_before.reverse() # Work through backwards, starting with the one just above
					for entry in entries_before
						original_top = entry.scope.entry.screenPos.y
						height = entry.$layout_el.height()
						original_bottom = original_top + height
						bottom = Math.min(original_bottom, previousTop - PADDING)
						top = bottom - height
						previousTop = top
						entry.$box_el.css(top: top)
						entry.$indicator_el.css(top: top)
						entry.$callout_el.addClass("rp-entry-callout-inverted")
						entry.$callout_el.css(top: top + line_height + 1, height: original_top - top)
						sl_console.log "ENTRY", {entry: entry.scope.entry, top}
				
				scope.$watch "reviewPanel.entryGeneration", (value) ->
					scope.$evalAsync () ->
						layout()
				
				scope.$on "review-panel:layout", () ->
					scope.$evalAsync () ->
						layout()
		}