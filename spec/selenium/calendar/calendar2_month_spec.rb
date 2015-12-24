require File.expand_path(File.dirname(__FILE__) + '/../common')
require File.expand_path(File.dirname(__FILE__) + '/../helpers/calendar2_common')

describe "calendar2" do
  include_context "in-process server selenium tests"

  before (:each) do
    Account.default.tap do |a|
      a.settings[:show_scheduler]   = true
      a.save!
    end
  end

  context "as a teacher" do
    before (:each) do
      course_with_teacher_logged_in
    end

    describe "main month calendar" do

      it "should remember the selected calendar view" do
        get "/calendar2"
        expect(find("#month")).to have_class('active')
        find('#agenda').click
        wait_for_ajaximations

        get "/calendar2"
        expect(find('#agenda')).to have_class('active')
      end

      it "should create an event through clicking on a calendar day", priority: "1", test_id: 138638 do
        create_middle_day_event
      end

      it "should show scheduler button if it is enabled" do
        get "/calendar2"
        expect(find("#scheduler")).not_to be_nil
      end

      it "should not show scheduler button if it is disabled" do
        account = Account.default.tap { |a| a.settings[:show_scheduler] = false; a.save! }
        get "/calendar2"
        find_all('.calendar_view_buttons .btn').each do |button|
          expect(button.text).not_to match(/scheduler/i)
        end
      end

      it "should drag and drop an event" do
        skip('drag and drop not working correctly')
        create_middle_day_event
        driver.action.drag_and_drop(find('.calendar .fc-event'), find('.calendar .fc-week:nth-child(2) .fc-last')).perform
        wait_for_ajaximations
        expect(CalendarEvent.last.start_at.strftime('%d')).to eq find('.calendar .fc-week:nth-child(2) .fc-last .fc-day-number').text
      end

      it "should create an assignment by clicking on a calendar day" do
        create_middle_day_assignment
      end

      it "more options link should go to calendar event edit page" do
        create_middle_day_event
        find('.fc-event').click
        expect(fj('.popover-links-holder:visible')).not_to be_nil
        driver.execute_script("$('.edit_event_link').hover().click()")
        expect_new_page_load { driver.execute_script("$('#edit_calendar_event_form .more_options_link').hover().click()") }
        expect(find('#editCalendarEventFull .btn-primary').text).to eq "Update Event"
        expect(find('#breadcrumbs').text).to include 'Calendar Events'
      end

      it "should go to assignment page when clicking assignment title" do
        name = 'special assignment'
        create_middle_day_assignment(name)
        keep_trying_until do
          fj('.fc-event.assignment').click
          wait_for_ajaximations
          if (fj('.view_event_link').displayed?)
            expect_new_page_load { driver.execute_script("$('.view_event_link').hover().click()") }
          end
          fj('h1.title').displayed?
        end

        expect(find('h1.title').text).to include(name)
      end

      it "more options link on assignments should go to assignment edit page" do
        name = 'super big assignment'
        create_middle_day_assignment(name)
        fj('.fc-event.assignment').click
        driver.execute_script("$('.edit_event_link').hover().click()")
        expect_new_page_load { driver.execute_script("$('.more_options_link').hover().click()") }
        expect(find('#assignment_name').attribute(:value)).to include(name)
      end

      it "should publish a new assignment when toggle is clicked" do
        create_published_middle_day_assignment
        wait_for_ajax_requests
        fj('.fc-event.assignment').click
        driver.execute_script("$('.edit_event_link').hover().click()")
        driver.execute_script("$('.more_options_link').hover().click()")
        expect(find('#assignment-draft-state')).not_to include_text("Not Published")
      end

      it "should delete an event" do
        create_middle_day_event('doomed event')
        fj('.fc-event:visible').click
        wait_for_ajaximations
        driver.execute_script("$('.delete_event_link').hover().click()")
        wait_for_ajaximations
        driver.execute_script("$('.ui-dialog:visible .btn-primary').hover().click()")
        wait_for_ajaximations
        expect(fj('.fc-event:visible')).to be_nil
        # make sure it was actually deleted and not just removed from the interface
        get("/calendar2")
        expect(fj('.fc-event:visible')).to be_nil
      end

      it "should delete an assignment" do
        create_middle_day_assignment
        keep_trying_until do
          fj('.fc-event').click()
          driver.execute_script("$('.delete_event_link').hover().click()")
          fj('.ui-dialog .ui-dialog-buttonset').displayed?
        end
        wait_for_ajaximations
        driver.execute_script("$('.ui-dialog:visible .btn-primary').hover().click()")
        wait_for_ajaximations
        expect(fj('.fc-event')).to be_nil
        # make sure it was actually deleted and not just removed from the interface
        get("/calendar2")
        expect(fj('.fc-event')).to be_nil
      end

      it "should not have a delete link for a frozen assignment" do
        PluginSetting.stubs(:settings_for_plugin).returns({"assignment_group_id" => "true"})
        frozen_assignment = @course.assignments.build(
            name: "frozen assignment",
            due_at: Time.zone.now,
            freeze_on_copy: true,
        )
        frozen_assignment.copied = true
        frozen_assignment.save!

        get("/calendar2")
        fj('.fc-event:visible').click
        wait_for_ajaximations
        expect(not_found('.delete_event_link')).to be
      end

      it "should correctly display next month on arrow press", priority: "1", test_id: 197555 do
        load_month_view
        quick_jump_to_date('Jan 1, 2012')
        change_calendar(:next)

        # Verify known dates in calendar header and grid
        expect(get_header_text).to include_text('February 2012')
        first_wednesday = '.fc-day-number.fc-wed:first'
        expect(fj(first_wednesday).text).to eq('1')
        expect(fj(first_wednesday).attribute('data-date')).to eq('2012-02-01')
        last_thursday = '.fc-day-number.fc-thu:last'
        expect(fj(last_thursday).text).to eq('1')
        expect(fj(last_thursday).attribute('data-date')).to eq('2012-03-01')
      end

      it "should correctly display previous month on arrow press", priority: "1", test_id: 419290 do
        load_month_view
        quick_jump_to_date('Jan 1, 2012')
        change_calendar(:prev)

        # Verify known dates in calendar header and grid
        expect(get_header_text).to include_text('December 2011')
        first_thursday = '.fc-day-number.fc-thu:first'
        expect(fj(first_thursday).text).to eq('1')
        expect(fj(first_thursday).attribute('data-date')).to eq('2011-12-01')
        last_saturday = '.fc-day-number.fc-sat:last'
        expect(fj(last_saturday).text).to eq('31')
        expect(fj(last_saturday).attribute('data-date')).to eq('2011-12-31')
      end

      it "should change the month" do
        get "/calendar2"
        old_header_title = get_header_text
        change_calendar
        new_header_title = get_header_text
        expect(old_header_title).not_to eq new_header_title
      end

      it "should navigate with jump-to-date control" do
        Account.default.change_root_account_setting!(:agenda_view, true)
        # needs to be 2 months out so it doesn't appear at the start of the next month
        eventStart = 2.months.from_now
        make_event(start: eventStart)

        get "/calendar2"
        expect(not_found('.fc-event')).to be
        eventStartText = eventStart.strftime("%Y %m %d")
        quick_jump_to_date(eventStartText)
        expect(find('.fc-event')).to be
      end

      it "should show section-level events, but not the parent event" do
        @course.default_section.update_attribute(:name, "default section!")
        s2 = @course.course_sections.create!(:name => "other section!")
        date = Date.today
        e1 = @course.calendar_events.build :title => "ohai",
                                           :child_event_data => [
                                               {:start_at => "#{date} 12:00:00", :end_at => "#{date} 13:00:00", :context_code => @course.default_section.asset_string},
                                               {:start_at => "#{date} 13:00:00", :end_at => "#{date} 14:00:00", :context_code => s2.asset_string},
                                           ]
        e1.updating_user = @user
        e1.save!

        get "/calendar2"
        events = ffj('.fc-event:visible')
        expect(events.size).to eq 2
        events.first.click

        details = find('.event-details')
        expect(details).to be
        expect(details.text).to include(@course.default_section.name)
        expect(details.find('.view_event_link')[:href]).to include "/calendar_events/#{e1.id}" # links to parent event
      end

      it "should have a working today button", priority: "1", test_id: 142041 do
        load_month_view
        date = Time.now.strftime("%-d")

        # Check for highlight to be present on this month
        # this class is also present on the mini calendar so we need to make
        #   sure that they are both present
        expect(find_all(".fc-state-highlight").size).to eq 4

        # Switch the month and verify that there is no highlighted day
        2.times { change_calendar }
        expect(find_all(".fc-state-highlight").size).to eq 0

        # Go back to the present month. Verify that there is a highlighted day
        change_calendar(:today)
        expect(find_all(".fc-state-highlight").size).to eq 4
        # Check the date in the second instance which is the main calendar
        expect(ffj(".fc-state-highlight")[1].text).to include(date)
      end

      it "should show the location when clicking on a calendar event" do
        location_name = "brighton"
        location_address = "cottonwood"
        make_event(:location_name => location_name, :location_address => location_address)
        load_month_view

        #Click calendar item to bring up event summary
        find(".fc-event").click

        #expect to find the location name and address
        expect(find('.event-details-content').text).to include_text(location_name)
        expect(find('.event-details-content').text).to include_text(location_address)
      end

      it "should bring up a calendar date picker when clicking on the month" do
        load_month_view

        #Click on the month header
        find('.navigation_title').click

        # Expect that a the event picker is present
        # Check various elements to verify that the calendar looks good
        expect(find('.ui-datepicker-header').text).to include_text(Time.now.utc.strftime("%B"))
        expect(find('.ui-datepicker-calendar').text).to include_text("Mo")
      end
    end
  end
end