define [
	"base"
], (App) ->
	App.directive "reviewPanelSorted", ($timeout) ->
		return  {
			link: (scope, element, attrs) ->
				previous_focused_entry_index = 0
				
				layout = () ->
					sl_console.log "LAYOUT"
					if scope.ui.reviewPanelOpen
						PADDING = 8
						TOOLBAR_HEIGHT = 38
					else
						PADDING = 4
						TOOLBAR_HEIGHT = 4
					
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
					
					line_height = scope.reviewPanel.rendererData.lineHeight

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

					# As we go backwards, we run the risk of pushing things off the top of the editor.
					# If we go through the entries before and assume they are as pushed together as they
					# could be, we can work out the 'ceiling' that each one can't go through. I.e. the first
					# on can't go beyond the toolbar height, the next one can't go beyond the bottom of the first
					# one at this minimum height, etc.
					heights = (entry.$layout_el.height() for entry in entries_before)
					previousMinTop = TOOLBAR_HEIGHT
					min_tops = []
					for height in heights
						min_tops.push previousMinTop
						previousMinTop += PADDING + height
					min_tops.reverse()

					positionLayoutEl = ($callout_el, original_top, top) ->
						if original_top <= top
							$callout_el.removeClass("rp-entry-callout-inverted")
							$callout_el.css(top: original_top + line_height - 1, height: top - original_top)
						else
							$callout_el.addClass("rp-entry-callout-inverted")
							$callout_el.css(top: top + line_height, height: original_top - top)

					# Put the focused entry as close to where it wants to be as possible
					focused_entry_top = Math.max(previousMinTop, focused_entry.scope.entry.screenPos.y)
					focused_entry.$box_el.css(top: focused_entry_top)
					focused_entry.$indicator_el.css(top: focused_entry_top)
					positionLayoutEl(focused_entry.$callout_el, focused_entry.scope.entry.screenPos.y, focused_entry_top)

					previousBottom = focused_entry_top + focused_entry.$layout_el.height()
					for entry in entries_after
						original_top = entry.scope.entry.screenPos.y
						height = entry.$layout_el.height()
						top = Math.max(original_top, previousBottom + PADDING)
						previousBottom = top + height
						entry.$box_el.css(top: top)
						entry.$indicator_el.css(top: top)
						positionLayoutEl(entry.$callout_el, original_top, top)
						sl_console.log "ENTRY", {entry: entry.scope.entry, top}

					previousTop = focused_entry_top
					entries_before.reverse() # Work through backwards, starting with the one just above
					for entry, i in entries_before
						original_top = entry.scope.entry.screenPos.y
						height = entry.$layout_el.height()
						original_bottom = original_top + height
						bottom = Math.min(original_bottom, previousTop - PADDING)
						top = Math.max(bottom - height, min_tops[i])
						previousTop = top
						entry.$box_el.css(top: top)
						entry.$indicator_el.css(top: top)
						positionLayoutEl(entry.$callout_el, original_top, top)
						sl_console.log "ENTRY", {entry: entry.scope.entry, top}
				
				scope.$applyAsync () ->
					layout()
				
				scope.$on "review-panel:layout", () ->
					scope.$applyAsync () ->
						layout()
				
				scope.$watch "reviewPanel.rendererData.lineHeight", () ->
					layout()

				## Scroll lock with Ace
				scroller = element
				list = element.find(".rp-entry-list-inner")
				
				# If we listen for scroll events in the review panel natively, then with a Mac trackpad
				# the scroll is very smooth (natively done I'd guess), but we don't get polled regularly
				# enough to keep Ace in step, and it noticeably lags. If instead, we borrow the manual
				# mousewheel/trackpad scrolling behaviour from Ace, and turn mousewheel events into
				# scroll events ourselves, then it makes the review panel slightly less smooth (barely)
				# noticeable, but keeps it perfectly in step with Ace.
				ace.require("ace/lib/event").addMouseWheelListener scroller[0], (e) ->
					deltaY = e.wheelY
					old_top = parseInt(list.css("top"))
					top = Math.min(0, old_top - deltaY * 4)
					list.css(top: top)
					scrollAce(-top)
					e.preventDefault()

				# Use these to avoid unnecessary updates. Scrolling one
				# panel causes us to scroll the other panel, but there's no
				# need to trigger the event back to the original panel.
				ignoreNextPanelEvent = false
				ignoreNextAceEvent = false

				scrollPanel = (scrollTop, height) ->
					if ignoreNextAceEvent
						ignoreNextAceEvent = false
					else
						ignoreNextPanelEvent = true
						list.height(height)
						# console.log({height, scrollTop, top: height - scrollTop})
						list.css(top: - scrollTop)
			
				scrollAce = (scrollTop) ->
					if ignoreNextPanelEvent
						ignoreNextPanelEvent = false
					else
						ignoreNextAceEvent = true
						scope.reviewPanelEventsBridge.emit "externalScroll", scrollTop
				
				scope.reviewPanelEventsBridge.on "aceScroll", scrollPanel
				scope.$on "$destroy", () ->
					scope.reviewPanelEventsBridge.off "aceScroll"
				
				scope.reviewPanelEventsBridge.emit "refreshScrollPosition"
		}	
