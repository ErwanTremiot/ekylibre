module TimeLineable
  extend ActiveSupport::Concern

  # Stopped_at is never included in the period because it is the started_at of the next period!
  included do
    validates_presence_of :started_at # , :if => :has_previous?
    validates_presence_of :stopped_at, :if => :has_followings?

    # scope :at,      lambda { |at| where("started_at <= ? AND (stopped_at IS NULL OR ? < stopped_at)", at, at) }
    scope :at,      lambda { |at| where(arel_table[:started_at].lteq(at).and(arel_table[:stopped_at].eq(nil).or(arel_table[:stopped_at].gt(at)))) }
    scope :after,   lambda { |at| where(arel_table[:started_at].gt(at)) }
    scope :before,  lambda { |at| where(arel_table[:started_at].lt(at)) }
    scope :current, -> { at(Time.now) }

    before_validation do
      if following = siblings.after(self.started_at).order(:started_at).first
        self.stopped_at = following.started_at
      else
        unless siblings.any?
          self.started_at ||= Time.new(1, 1, 1, 0, 0, 0, "+00:00")
        end
        self.stopped_at = nil
      end
    end

    validate do
      if self.started_at and self.stopped_at
        if self.stopped_at <= self.started_at
          errors.add(:stopped_at, :posterior, to: self.started_at.l)
        end
      end
    end

    before_update do
      old = old_record
      if old.started_at != self.started_at and previous = old.previous
        previous.update_column(:stopped_at, old.stopped_at)
      end
    end

    after_save do
      if previous = siblings.before(self.started_at).reorder("started_at DESC").first || siblings.where(started_at: nil).first
        previous.update_column(:stopped_at, self.started_at)
      end
    end

    after_destroy do
      if previous = self.previous
        self.previous.update_column(:stopped_at, self.stopped_at)
      end
    end
  end

  def previous
    return nil unless self.started_at
    return @previous ||= siblings.find_by(stopped_at: self.started_at)
  end

  def following
    return nil unless self.stopped_at
    return @following ||= siblings.find_by(started_at: self.stopped_at)
  end

  def has_previous?
    siblings.before(self.started_at).any?
  end

  def has_followings?
    siblings.after(self.started_at).any?
  end

  private

  def siblings
    raise NotImplementedError, "Private method :siblings must be implemented"
  end

end
