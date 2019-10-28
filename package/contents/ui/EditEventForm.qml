import QtQuick 2.0
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.plasma.components 3.0 as PlasmaComponents3

Loader {
	id: editEventForm
	active: false
	visible: active
	Layout.fillWidth: true
	sourceComponent: Component {
		MouseArea {
			id: editEventItem

			onClicked: focus = true

			implicitWidth: editEventGrid.implicitWidth
			implicitHeight: editEventGrid.implicitHeight

			readonly property var event: events.get(index)

			Component.onCompleted: {
				agendaScrollView.positionViewAtEvent(agendaItemIndex, eventItemIndex)
				editSummaryTextField.forceActiveFocus()

				logger.debugJSON('EditEventForm.event', event)
			}

			function isEmpty(s) {
				return typeof s === "undefined" || s === ""
			}
			function hasChanged(a, b) {
				// logger.log('hasChanged', a != b)
				// logger.log('\t', JSON.stringify(a), typeof a, isEmpty(a))
				// logger.log('\t', JSON.stringify(b), typeof b, isEmpty(b))
				return a != b && !(isEmpty(a) && isEmpty(b))
			}
			function populateIfChanged(args, propKey, newValue) {
				var changed = hasChanged(event[propKey], newValue)
				// logger.log(propKey, changed, event[propKey], newValue)
				if (changed) {
					args[propKey] = newValue
				}
			}
			function populateIfDateChanged(args, propKey, newValue) {
				var changedDate = hasChanged(event[propKey]['date'], newValue['date'])
				var changedDateTime = hasChanged(event[propKey]['dateTime'], newValue['dateTime'])
				var changedTimeZone = hasChanged(event[propKey]['timeZone'], newValue['timeZone'])
				var changed = changedDate || changedDateTime || changedTimeZone
				// logger.logJSON('populateIfDateChanged', propKey, changed, event[propKey], newValue)
				// logger.log('\t', changedDate, changedDateTime, changedTimeZone)
				if (changed) {
					args[propKey] = newValue
				}
			}
			function getChanges() {
				var args = {}
				populateIfChanged(args, 'summary', editSummaryTextField.text)
				populateIfDateChanged(args, 'start', durationSelector.getStartObj())
				populateIfDateChanged(args, 'end', durationSelector.getEndObj())
				populateIfChanged(args, 'location', editLocationTextField.text)
				populateIfChanged(args, 'description', editDescriptionTextField.text)
				return args
			}
			function submit() {
				logger.log('editEventItem.submit()')
				var event = events.get(index)
				logger.debugJSON('event', event)

				if (event.calendarId != calendarSelector.selectedCalendarId) {
					// TODO: Move event
					// TODO: Call setProperties after moving or vice versa.
					// https://developers.google.com/calendar/v3/reference/events/move
				}

				var args = getChanges()
				eventModel.setEventProperties(event.calendarId, event.id, args)
			}

			function cancel() {
				editEventForm.active = false
			}

			//---- Testing
			// Connections {
			// 	target: durationSelector
			// 	onStartDateTimeChanged: logger.logJSON('onStartDateTimeChanged', editEventItem.getChanges())
			// 	onEndDateTimeChanged: logger.logJSON('onEndDateTimeChanged', editEventItem.getChanges())
			// }

			//----
			GridLayout {
				id: editEventGrid
				anchors.left: parent.left
				anchors.right: parent.right
				columns: 2

				//---

				PlasmaComponents3.TextField {
					id: editSummaryTextField
					Layout.fillWidth: true
					Layout.columnSpan: 2
					placeholderText: i18n("Event Title")
					text: model.summary
					onAccepted: {
						logger.debug('editSummaryTextField.onAccepted', text)
						editEventItem.submit()
					}

					Keys.onEscapePressed: editEventItem.cancel()
				}

				//---

				DurationSelector {
					id: durationSelector
					showTime: !isAllDayCheckBox.checked
					Layout.fillWidth: true
					Layout.columnSpan: 2

					startDateTime: model.startDateTime || new Date()
					endDateTime: model.endDateTime || new Date()

					function dateTimeString(d) {
						return d.toISOString()
					}
					function dateString(d) {
						return d.toISOString().substr(0, 10)
					}
					function getStartObj() {
						if (showTime) {
							return { dateTime: dateTimeString(startDateTime), timeZone: event.start.timeZone }
						} else { // All day
							return { date: dateString(startDateTime) }
						}
					}
					function getEndObj() {
						if (showTime) {
							return { dateTime: dateTimeString(endDateTime), timeZone: event.end.timeZone }
						} else { // All day
							// Events end at "midnight" the next day.
							// See parseEventsForDate() functions for more info.
							var dt = new Date(endDateTime)
							dt.setDate(dt.getDate() + 1)
							return { date: dateString(dt) }
						}
					}
				}

				RowLayout {
					Layout.columnSpan: 2

					PlasmaComponents3.CheckBox {
						id: isAllDayCheckBox
						text: i18n("All Day")
						checked: !!event.start.date
						enabled: durationSelector.enabled
					}
				}

				//---

				EventPropertyIcon {
					source: "mark-location-symbolic"
				}
				PlasmaComponents3.TextField {
					id: editLocationTextField
					Layout.fillWidth: true
					placeholderText: i18n("Add location")
					text: model.location || ""
					onAccepted: {
						logger.debug('editLocationTextField.onAccepted', text)
						editEventItem.submit()
					}

					Keys.onEscapePressed: editEventItem.cancel()
				}

				EventPropertyIcon {
					source: "view-calendar-day"
				}
				PlasmaComponents.ComboBox {
					id: calendarSelector
					Layout.fillWidth: true
					model: [i18n("[No Calendars]")]
					enabled: false
					Component.onCompleted: {
						// AgendaView.__
						// logger.debug('populateCalendarSelector', calendarSelector, event.calendarId)
						populateCalendarSelector(calendarSelector, event.calendarId)
					}
				}

				EventPropertyIcon {
					source: "x-shape-text"
					Layout.fillHeight: false
					Layout.alignment: Qt.AlignTop
				}
				PlasmaComponents3.TextArea {
					id: editDescriptionTextField
					placeholderText: i18n("Add description")
					text: model.description || ""

					Layout.fillWidth: true
					Layout.preferredHeight: contentHeight + (20 * units.devicePixelRatio)

					Keys.onEscapePressed: editEventItem.cancel()

					Keys.onEnterPressed: _onEnterPressed(event) // ?
					Keys.onReturnPressed: _onEnterPressed(event) // What's triggered on a US Keyboard
					function _onEnterPressed(event) {
						// console.log('onEnterPressed', event.key, event.modifiers)
						if ((event.modifiers & Qt.ShiftModifier) || (event.modifiers & Qt.ControlModifier)) {
							editEventItem.submit()
						} else {
							event.accepted = false
						}
					}
				}

				RowLayout {
					Layout.columnSpan: 2
					spacing: 4 * units.devicePixelRatio
					Item {
						Layout.fillWidth: true
					}
					PlasmaComponents.Button {
						iconName: "document-save"
						text: i18n("&Save")
						implicitWidth: minimumWidth
						onClicked: editEventItem.submit()
					}
					PlasmaComponents.Button {
						iconName: "dialog-cancel"
						text: i18n("&Cancel")
						implicitWidth: minimumWidth
						onClicked: editEventItem.cancel()
					}
				}
			}

		}
	}
}
