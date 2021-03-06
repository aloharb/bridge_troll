class Events::EmailsController < ApplicationController
  before_filter :authenticate_user!, :validate_organizer!, :find_event

  def new
    @email = @event.event_emails.build(
      attendee_group: 'All',
    )
    assign_ivars
  end

  def create
    email_params = params[:event_email]

    if email_params[:attendee_group] == 'All'
      recipient_rsvps = @event.rsvps.where(role_id: [Role::VOLUNTEER.id, Role::STUDENT.id]).includes(:user)
    else
      recipient_rsvps = @event.rsvps.where(role_id: email_params[:attendee_group]).includes(:user)
    end

    unless email_params[:include_waitlisted]
      recipient_rsvps = recipient_rsvps.where(waitlist_position: nil)
    end

    @email = @event.event_emails.build(
      subject: email_params[:subject],
      body: email_params[:body],
      sender: current_user,
      recipient_rsvp_ids: recipient_rsvps.map(&:id),
      attendee_group: email_params[:attendee_group].to_i,
      include_waitlisted: email_params[:include_waitlisted]
    )

    unless @email.valid?
      assign_ivars
      return render :new
    end

    EventMailer.from_organizer(
      sender: current_user,
      recipients: recipient_rsvps.map { |rsvp| rsvp.user.email },
      subject: email_params[:subject],
      body: email_params[:body],
      event: @event
    ).deliver

    @email.save!

    redirect_to organize_event_path(@event), notice: "Your mail has been sent. Woo!"
  end

  def show
    @email = @event.event_emails.find(params[:id])
  end

  private

  def find_event
    @event = Event.find_by_id(params[:event_id])
  end

  def assign_ivars
    @rsvps = @event.rsvps.where(role_id: [Role::VOLUNTEER.id, Role::STUDENT.id]).includes(:user)
    @emails = @event.event_emails.order(:created_at)

    @email_recipients = {}
    @emails.each do |email|
      @email_recipients[email.id] = {
        total: email.recipient_rsvps.length,
        volunteers: 0,
        students: 0
      }
      email.recipient_rsvps.each do |rsvp|
        if rsvp.role == Role::VOLUNTEER
          @email_recipients[email.id][:volunteers] += 1
        end
        if rsvp.role == Role::STUDENT
          @email_recipients[email.id][:students] += 1
        end
      end
    end
  end
end
