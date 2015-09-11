from app import app, db
from datetime import datetime, date, timedelta
from sqlalchemy.ext.associationproxy import association_proxy

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), index=True, unique=True)
    fullname = db.Column(db.String(120), index=True)
    registered_date = db.Column(db.DateTime, default=datetime.utcnow())
    last_seen = db.Column(db.DateTime, default=datetime.utcnow())
    last_ip = db.Column(db.String(15))
    rooms = db.relationship('Room', backref='creator', lazy='dynamic')

    # Links to rooms table (curators)
    curated_rooms = db.relationship('RoomCurator', backref=db.backref('user', lazy='joined'), lazy='dynamic')

    # Links to rooms table (users)
    joined_rooms = db.relationship('RoomUser', backref=db.backref('user', lazy='joined'), lazy='dynamic')

    # Links to rooms table (users)
    recent_rooms = db.relationship('RecentRoom', backref=db.backref('user', lazy='joined'), lazy='dynamic')

    # Links to upvotes table
    upvoted_tracks = db.relationship('TrackUpvote', backref=db.backref('user', lazy='joined'), lazy='dynamic')

    def __repr__(self):
        return '*** User *** \nID: %s \nUsername: %s \nFullname: %s \nRegistered: %s \nLast Seen: %s \nLast IP: %s \n' % (self.id, self.username, self.fullname, self.registered_date, self.last_seen, self.last_ip)

    def get_curated_rooms(self):
        return RoomCurator.query.join('user').filter(RoomCurator.user_id==self.id).order_by(RoomCurator.id.desc())

    def get_joined_rooms(self):
        return RoomUser.query.join('user').filter(RoomUser.user_id==self.id).order_by(RoomUser.id.desc())

class Room(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), index=True)
    description = db.Column(db.String(256))
    private = db.Column(db.Integer, index=True)
    active_users = db.Column(db.Integer, default=0)
    creator_user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    password = db.Column(db.String(128))

    # Links to users table (curators)
    curators = db.relationship('RoomCurator', backref=db.backref('room', lazy='joined'), lazy='dynamic')

    # Links to users table (users)
    users = db.relationship('RoomUser', backref=db.backref('room', lazy='joined'), lazy='dynamic')

    # Links to users table for recent rooms
    rceent_users = db.relationship('RecentRoom', backref=db.backref('room', lazy='joined'), lazy='dynamic')

    def __repr__(self):
        return '*** Room *** \nID: %s \nName: %s \nPrivate: %s \nActive Users: %s \nCreator: %s \n' % (self.id, self.name, self.private, self.active_users, self.creator_user_id)

    def get_curators(self):
        return RoomCurator.query.join('room').filter(RoomCurator.room_id==self.id).all()

    def get_users(self):
        return RoomUser.query.join('room').filter(RoomUser.room_id==self.id).all()

class RoomCurator(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    room_id = db.Column(db.Integer, db.ForeignKey('room.id'))
    created_date = db.Column(db.DateTime, default=datetime.utcnow())

    def __repr__(self):
        return '*** RoomCurator *** \nUser ID: %s \nRoom ID: %s \nRecord Creation Date: %s \n' % (self.user_id, self.room_id, self.created_date)

class RoomUser(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    room_id = db.Column(db.Integer, db.ForeignKey('room.id'))
    joined_date = db.Column(db.DateTime, default=datetime.utcnow())
    sid = db.Column(db.Integer)

    def __repr__(self):
        return '*** RoomUser *** \nUser ID: %s \nRoom ID: %s \nRecord Creation Date: %s \nSID: %s \n' % (self.user_id, self.room_id, self.joined_date, self.sid)

class RecentRoom(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    room_id = db.Column(db.Integer, db.ForeignKey('room.id'))
    joined_date = db.Column(db.DateTime, default=datetime.utcnow())

    def __repr__(self):
        return '*** RecentRoom *** \nUser ID: %s \nRoom ID: %s \nRecord Joined Date: %s \n' % (self.user_id, self.room_id, self.joined_date)

class RoomTrack(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    room_id = db.Column(db.Integer, db.ForeignKey('room.id'))
    track_id = db.Column(db.String(128))
    track_duration = db.Column(db.String(15))
    upvotes = db.Column(db.Integer, default=0)
    added_datetime = db.Column(db.DateTime, default=datetime.utcnow())
    added_user_id = db.Column(db.Integer, db.ForeignKey('user.id'))

    # Links to users table
    upvote_users = db.relationship('TrackUpvote', backref=db.backref('room_track', lazy='joined'), lazy='dynamic')

    def __repr__(self):
        return "%s" % self.id
        #return '*** RoomTrack *** \nRoom ID: %s \nTrack ID: %s \nTrack Duration: %s \nUpvotes: %s \nAdded Date: %s \nAdded User ID: %s \n' % (self.room_id, self.track_id, self.track_duration, self.upvotes, self.added_datetime, self.added_user_id)

class TrackUpvote(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    track_id = db.Column(db.Integer, db.ForeignKey('room_track.id'))
    upvote_date = db.Column(db.DateTime, default=datetime.utcnow())

    def __repr__(self):
        return "%s" % self.id

class Session(db.Model):
    session_id = db.Column(db.String(64), primary_key=True)
    username = db.Column(db.String(64), index=True)
    ip = db.Column(db.String(15))
    last_seen = db.Column(db.DateTime, default=datetime.utcnow())

    def __repr__(self):
        return '*** Session *** \nUser: %s \nIP: %s \nLast Seen: %s \nSession ID: %s \n' % (self.username, self.ip, self.last_seen, self.session_id)
