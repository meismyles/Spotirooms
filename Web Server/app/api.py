from flask import Flask, redirect, session, url_for, escape, request, jsonify, g, abort
from flask.ext.httpauth import HTTPBasicAuth
import flask.ext.socketio as sio
from app import app, db, model, socketio
from config import SECRET_KEY, CLIENT_ID, AUTH_TOKEN_TTL
from datetime import datetime, timedelta
from .model import *
from uuid import uuid4
from six.moves import urllib
import threading

auth = HTTPBasicAuth()
active_room_startTimes = {}
active_room_tracks = {}
active_track_duartions = {}
active_room_timers = {}

# If Authentication required, this code is executed
@auth.verify_password
def verify(session_id, _=None):
    # Get users session (if one exists)
    session = Session.query.filter_by(session_id=session_id).first()
    if session:
        g.user = User.query.filter_by(username=session.username).first()
        g.user.last_seen = datetime.utcnow()
        session.last_seen = datetime.utcnow()
        db.session.commit()
        return True

    # Otherwise session invalid. Clear all other invalid sessions.
    Session.query.filter(Session.last_seen < (datetime.utcnow()-timedelta(days=1))).delete()
    db.session.commit()
    print "*** FAILED TO VERIFY SESSION ID ***"
    return False

@app.route('/api/login', methods=['POST'])
def login():
    username = request.json.get('username', None)
    fullname = request.json.get('fullname', None)
    received_client_id = request.json.get('client_id')

    if username is None or username == '' or fullname is None or fullname == '' or received_client_id is None or received_client_id == '':
        abort(400, "Missing Arguments")    # missing arguments

    if received_client_id == CLIENT_ID:
        user = User.query.filter_by(username=username).first()
        # If user doesn't exist, create them
        if not user:
            user = new_user()
        # Remove stale session
        old_session = Session.query.filter_by(username=username).first()
        if old_session:
            db.session.delete(old_session)
        # Generate new session
        ip = request.environ.get('REMOTE_ADDR', 0)
        session_id = str(uuid4())
        session = Session(session_id=session_id, username=username, ip=ip, last_seen=datetime.utcnow())
        db.session.add(session)

        # Update details
        print "***** UPDATING DETAILS *****"
        user.last_ip = ip
        user.last_seen = datetime.utcnow()
        db.session.commit()
        return (jsonify({'token': session_id}))
    else:
        abort(401, "Invalid Client")    # invalid client id

def new_user():
    print "***** CREATING NEW USER *****"
    username = request.json.get('username', None)
    fullname = request.json.get('fullname', None)
    ip = request.environ.get('REMOTE_ADDR', 0)
    user = User(username=username, fullname=fullname, last_ip=ip)
    db.session.add(user)
    db.session.commit()
    return user

@app.route('/api/session_check', methods=['POST'])
@auth.login_required
def session_check():
    # If reaches here then session token is valid
    return (jsonify(success="Session token is valid"))

@app.route('/api/create_room', methods=['POST'])
@auth.login_required
def create_room():
    print "***** CREATING NEW ROOM *****"
    name = request.json.get('name', None)
    description = request.json.get('description', None)
    hashpass = request.json.get('pass', None)
    private = request.json.get('private', None)

    if hashpass == '':
        hashpass = None

    if name is None or name == '' or private is None or private == '':
        abort(400, "Missing Arguments")    # missing arguments

    if len(Room.query.filter_by(name=name).all()) == 0:
        new_room = Room(name=name, description=description, private=private, creator_user_id=g.user.id, password=hashpass)
        g.room = new_room
        db.session.add(new_room)
        db.session.commit()

        new_room_curator()
        return (jsonify(room_id=g.room.id))
    else:
        abort(400, "A room with this name already exists.")

@app.route('/api/check_pass', methods=['POST'])
@auth.login_required
def check_pass():
    room_id = request.json.get('room_id', None)
    hashpass = request.json.get('pass', None)

    if hashpass == '':
        hashpass = None

    if len(Room.query.filter_by(id=room_id).filter_by(password=hashpass).all()) == 1:
        return (jsonify(data=1))
    else:
        abort(400, "Incorrect Password.")

@app.route('/api/delete_room', methods=['POST'])
@auth.login_required
def delete_room():
    room_id = request.json.get('room_id', None)
    if room_id is None:
        abort(400, "No room specified")
    g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        abort(400, "Invalid Room")

    if len(RoomCurator.query.filter_by(user_id=g.user.id).filter_by(room_id=g.room.id).all()) == 1:
        empty_room()
        RoomCurator.query.filter_by(room_id=g.room.id).delete() # revoke room curators
        RoomTrack.query.filter_by(room_id=g.room.id).delete() # delete room tracks
        Room.query.filter_by(id=g.room.id).delete() # delete room
        db.session.commit()
        return 'success'
    else:
        abort(400, "User not a curator specified room")

@app.route('/api/get_rooms', methods=['POST'])
@auth.login_required
def get_rooms():
    rooms = Room.query.order_by(Room.name.asc()).all()
    if len(rooms) > 0:
        response = []
        for r in rooms:
            r_info = {
                'room_id': r.id,
                'name': r.name,
                'description': r.description,
                'private': r.private,
                'active_users': r.active_users,
                'creator_user_id': r.creator_user_id
            }
            response.append(r_info)
        return (jsonify(results=response))
    else:
        abort(400, "No rooms available")

@app.route('/api/get_curated_rooms', methods=['POST'])
@auth.login_required
def get_curated_rooms():
    rooms = RoomCurator.query.filter_by(user_id=g.user.id).all()
    if len(rooms) > 0:
        response = []
        for temp in rooms:
            r = Room.query.filter_by(id=temp.room_id).first()
            r_info = {
                'room_id': r.id,
                'name': r.name,
                'private': r.private,
                'active_users': r.active_users,
                'creator_user_id': r.creator_user_id
            }
            response.append(r_info)
        return (jsonify(results=response))
    else:
        abort(400, "No rooms available")

@app.route('/api/get_recent_rooms', methods=['POST'])
@auth.login_required
def get_recent_rooms():
    rooms = RecentRoom.query.filter_by(user_id=g.user.id).order_by(RecentRoom.id.desc()).all()
    if len(rooms) > 0:
        response = []
        for temp in rooms:
            r = Room.query.filter_by(id=temp.room_id).first()
            r_info = {
                'room_id': r.id,
                'name': r.name,
                'private': r.private,
                'active_users': r.active_users,
                'creator_user_id': r.creator_user_id
            }
            response.append(r_info)
        return (jsonify(results=response))
    else:
        abort(400, "No rooms available")

@app.route('/api/new_room_curator', methods=['POST'])
@auth.login_required
def new_room_curator():
    # If request is coming directly to this route, g.room will be None
    if g.get('room', None) is None:
        room_id = request.json.get('room_id', None)
        if room_id is None:
            abort(400, "No room specified")
        g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        abort(400, "Invalid Room")

    if RoomCurator.query.filter_by(user_id=g.user.id).filter_by(room_id=g.room.id).first() is None:
        print "***** NEW ROOM CURATOR *****"
        new_room_curator = RoomCurator(user_id=g.user.id, room_id=g.room.id)
        db.session.add(new_room_curator)
        db.session.commit()
        return 'success'
    else:
        abort(400, "Already a curator of specified room")

@app.route('/api/remove_room_curator', methods=['POST'])
@auth.login_required
def remove_room_curator():
    room_id = request.json.get('room_id', None)
    if room_id is None:
        abort(400, "No room specified")
    g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        abort(400, "Invalid Room")

    # Check user is a curator of respective room
    room_curator = RoomCurator.query.filter_by(user_id=g.user.id).filter_by(room_id=g.room.id).first()
    if room_curator is not None:
        if len(RoomCurator.query.all()) < 2:
            abort(400, "Must be atleast one curator per room")
        else:
            print "***** REMOVING ROOM CURATOR *****"
            db.session.delete(room_curator)
            db.session.commit()
            return 'success'
    else:
        abort(400, "User not a curator of specified room")

def join_room(room_id=None, sid=None):
    if room_id is None:
        return "No room specified."
    if sid is None:
        return "No socket session ID."

    g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        return "Invalid Room."

    room_user = RoomUser.query.filter_by(user_id=g.user.id).filter_by(room_id=g.room.id).first()
    if room_user is None:
        print "*** USER JOINED ROOM: %s - %s ***" % (g.room.id, g.room.name)
        new_room_user = RoomUser(user_id=g.user.id, room_id=g.room.id, sid=sid)
        g.room.active_users += 1
        db.session.add(new_room_user)
        db.session.commit()
        add_recent_room(room_id=room_id)
        return True
    else:
        g.room.active_users -= 1
        db.session.delete(room_user)
        db.session.commit()
        return "Already a user of specified room. Please try joining again."

def add_recent_room(room_id=None):
    if room_id is None:
        return "No room specified."

    g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        return "Invalid Room."

    check_exists = RecentRoom.query.filter_by(user_id=g.user.id).filter_by(room_id=room_id).first()
    if check_exists is not None:
        db.session.delete(check_exists)
    else:
        recent_rooms = RecentRoom.query.filter_by(user_id=g.user.id).order_by(RecentRoom.id.asc()).all()
        if len(recent_rooms) > 6:
            for room in recent_rooms:
                db.session.delete(room)
                break

    new_recent_room = RecentRoom(user_id=g.user.id, room_id=room_id)
    db.session.add(new_recent_room)
    db.session.commit()

def leave_room(sid=None):
    #if room_id is None:
    #    return "No room specified."
    if sid is None:
        return "No socket session ID."

    # Check user is a user of respective room
    room_user = RoomUser.query.filter_by(sid=sid).first()

    g.room = Room.query.filter_by(id=room_user.room_id).first()

    if g.room is None:
        return "Invalid Room."

    if room_user is not None:
        print "*** USER LEAVING ROOM: %s - %s ***" % (g.room.id, g.room.name)
        g.room.active_users -= 1
        db.session.delete(room_user)
        db.session.commit()
        return True
    else:
        return "User not in specified room."

@app.route('/api/empty_room', methods=['POST'])
@auth.login_required
def empty_room():
    # If request is coming directly to this route, g.room will be None
    if g.get('room', None) is None:
        room_id = request.json.get('room_id', None)
        if room_id is None:
            abort(400, "No room specified")
        g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        abort(400, "Invalid Room")

    # Check user is a curator of respective room
    room_curator = RoomCurator.query.filter_by(user_id=g.user.id).filter_by(room_id=g.room.id).first()
    if room_curator is not None:
        print "*** EMPTYING ROOM: %s ***" % g.room.id
        RoomUser.query.filter_by(room_id=1).delete()
        g.room.active_users = 0
        db.session.commit()
        return 'success'
    else:
        abort(400, "User not a curator of specified room")

def add_track(room_id=None, track_id=None, track_duration=None):
    if room_id is None:
        return "No room specified."
    if track_id is None:
        return "No track specified."
    if track_duration is None:
        return "No duration specified."

    g.room = Room.query.filter_by(id=room_id).first()

    if g.room is None:
        return "Invalid Room."

    if RoomTrack.query.filter_by(track_id=track_id).filter_by(room_id=g.room.id).first() is None:
        print "*** TRACK ADDED TO ROOM: %s - %s ***" % (track_id, g.room.name)
        g.new_room_track = RoomTrack(added_user_id=g.user.id, room_id=g.room.id, track_id=track_id, track_duration=track_duration)
        db.session.add(g.new_room_track)
        db.session.commit()
        return True
    else:
        return "Track already in specified room."

def upvote_track(roomtrack_id=None):
    if roomtrack_id is None:
        return "No roomtrack ID specified."

    if TrackUpvote.query.filter_by(track_id=roomtrack_id).filter_by(user_id=g.user.id).first() is None:
        print "*** TRACK UPVOTED ID: %s - USER ID: %s ***" % (roomtrack_id, g.user.id)
        g.new_track_upvote = TrackUpvote(user_id=g.user.id, track_id=roomtrack_id)
        db.session.add(g.new_track_upvote)
        roomtrack = RoomTrack.query.filter_by(id=roomtrack_id).first()
        roomtrack.upvotes = roomtrack.upvotes+1
        db.session.add(roomtrack)
        db.session.commit()
        return True
    else:
        return "Track already been upvoted by user."

def get_room_tracks(room_id=None):
    if room_id is None:
        return "No room specified."

    tracks = RoomTrack.query.filter_by(room_id=room_id).order_by(RoomTrack.upvotes.desc()).all()
    if len(tracks) > 0:
        response = []
        for t in tracks:
            has_upvoted = 0 if TrackUpvote.query.filter_by(track_id=t.id).filter_by(user_id=g.user.id).first() is None else 1
            t_info = {
                'id': t.id,
                'track_id': t.track_id,
                'upvotes': t.upvotes,
                'has_upvoted': has_upvoted,
                'added_datetime': str(t.added_datetime)
            }
            response.append(t_info)
        return response
    else:
        return "nil"

def get_room_tracks_after_upvote(room_id=None, user_id=None):
    if room_id is None:
        return "No room specified."

    tracks = RoomTrack.query.filter_by(room_id=room_id).order_by(RoomTrack.upvotes.desc()).all()
    if len(tracks) > 0:
        response = []
        for t in tracks:
            print TrackUpvote.query.filter_by(track_id=t.id).filter_by(user_id=g.user.id).first()
            has_upvoted = 0 if TrackUpvote.query.filter_by(track_id=t.id).filter_by(user_id=g.user.id).first() is None else 1
            t_info = {
                'id': t.id,
                'track_id': t.track_id,
                'upvotes': t.upvotes,
                'has_upvoted': has_upvoted,
                'added_datetime': str(t.added_datetime)
            }
            response.append(t_info)
        return response
    else:
        return "nil"

def sync_play(*args):
    room_id = args[0]
    repeat = args[1] if len(args) == 2 else False

    global active_room_startTimes
    global active_room_tracks
    global active_track_duartions
    global active_room_timers

    with app.test_request_context():
        # Check if users still in room
        if room_id in sio.all_rooms(namespace="/spotirooms"):
            room_id = str(room_id)
            if room_id in active_room_startTimes: # room active, pass current info
                tooFast = True
                while tooFast: # run again if user joined to quickly during setup
                    if room_id in active_room_tracks and room_id in active_track_duartions:
                        tooFast = False
                        if (datetime.utcnow() - datetime(1970,1,1)).total_seconds() >= (active_room_startTimes[room_id] + active_track_duartions[room_id]): # track has expired
                            RoomTrack.query.filter_by(id=active_room_tracks[room_id]).delete()
                            TrackUpvote.query.filter_by(id=active_room_tracks[room_id]).delete()
                            db.session.commit()
                            next_track = RoomTrack.query.filter_by(room_id=int(room_id)).order_by(RoomTrack.upvotes.desc()).first()
                            if next_track is not None:
                                print "*** ROOM IS ACTIVE AND GETTING NEXT TRACK"
                                next_track.upvotes = 99999
                                db.session.commit()
                                active_room_startTimes[room_id] = (datetime.utcnow() - datetime(1970,1,1)).total_seconds()
                                active_room_tracks[room_id] = next_track.id
                                active_track_duartions[room_id] = int(next_track.track_duration.split('.')[0])
                            else:
                                print "*** NO MORE TRACKS TO PLAY"
                                active_room_startTimes.pop(room_id, False)
                                active_room_tracks.pop(room_id, False)
                                active_track_duartions.pop(room_id, False)
                                active_room_timers.pop(room_id, False)
                                return False
            else: # room was not active, start it
                next_track = RoomTrack.query.filter_by(room_id=int(room_id)).order_by(RoomTrack.upvotes.desc()).first()
                if next_track is not None:
                    print "*** ROOM WASN'T ACTIVE AND GETTING NEXT TRACK"
                    next_track.upvotes = 99999
                    db.session.commit()
                    active_room_startTimes[room_id] = (datetime.utcnow() - datetime(1970,1,1)).total_seconds()
                    active_room_tracks[room_id] = next_track.id
                    active_track_duartions[room_id] = int(next_track.track_duration.split('.')[0])
                else:
                    print "*** NO TRACK TO PLAY"
                    active_room_startTimes.pop(room_id, False)
                    active_room_tracks.pop(room_id, False)
                    active_track_duartions.pop(room_id, False)
                    return False
        else:
            # Close the room
            print "**** CLOSING ROOM"
            room_id = str(room_id)
            RoomTrack.query.filter_by(id=active_room_tracks[room_id]).delete()
            TrackUpvote.query.filter_by(id=active_room_tracks[room_id]).delete()
            db.session.commit()
            active_room_startTimes.pop(room_id, False)
            active_room_tracks.pop(room_id, False)
            active_track_duartions.pop(room_id, False)
            active_room_timers.pop(room_id, False)
            return False

        # Pass current track start time (unix timestamp)
        sio.custom_emit('start playing success', {'start_time': active_room_startTimes[room_id]}, room=int(room_id)) # sets namespace manually inside custom_emit() it AHACK
        if room_id not in active_room_timers or repeat is True:
            active_room_timers[room_id] = True
            threading.Timer(active_track_duartions[room_id]+0.3, sync_play, [int(room_id), True]).start() # plus 0.3 seconds to account for processing/latency
        return True

def stop_playing(room_id=None):
    pass
    # Call this when last person in room leaves. Pop the start time from the dict.

############################################################
# Websocket Methods
############################################################

@socketio.on('connect', namespace='/spotirooms')
def socket_connect():
    print "*** Client Connected ***"

@socketio.on('join room', namespace='/spotirooms')
def socket_join_room(message):
    session_id = message['session_id']
    room_id = message['room_id']

    if verify(session_id):
        join_attempt = join_room(room_id, request.sid)
        if join_attempt is True:
            sio.join_room(room_id)
            sync_play(room_id)
            sio.emit('join room success', {'data': get_room_tracks(room_id)})
        else:
            sio.emit('join room fail', {'data': join_attempt})
    else:
        sio.emit('join room fail', {'data': 'Invalid session.'})

@socketio.on('add track', namespace='/spotirooms')
def socket_add_track(message):
    session_id = message['session_id']
    room_id = message['room_id']
    track_id = message['track_id']
    track_duration = message['track_duration']

    if verify(session_id):
        add_attempt = add_track(room_id, track_id, track_duration)
        if add_attempt is True:
            sio.emit('add track success', {'id': g.new_room_track.id,
                                            'track_id': track_id,
                                            'added_datetime': str(g.new_room_track.added_datetime),
                                            'upvotes': g.new_room_track.upvotes,
                                            'has_upvoted': 0,
                                            }, room=room_id)
            global active_room_startTimes
            if str(room_id) not in active_room_startTimes:
                print "*** STARTING PLAYBACK ***"
                sync_play(room_id)
        else:
            sio.emit('add track fail', {'data': add_attempt})
    else:
        sio.emit('add track fail', {'data': 'Invalid session.'})

@socketio.on('upvote track', namespace='/spotirooms')
def socket_upvote_track(message):
    session_id = message['session_id']
    room_id = message['room_id']
    roomtrack_id = message['roomtrack_id']

    if verify(session_id):
        upvote_attempt = upvote_track(roomtrack_id)
        if upvote_attempt is True:
            sio.emit('upvote track success', {'data': 'Get new tracklist'}, room=room_id)

@socketio.on('get tracklist', namespace='/spotirooms')
def socket_get_tracklist(message):
    session_id = message['session_id']
    room_id = message['room_id']

    if verify(session_id):
        session = Session.query.filter_by(session_id=session_id).first()
        if session:
            user = User.query.filter_by(username=session.username).first()
            sio.emit('tracklist update', {'data': get_room_tracks_after_upvote(room_id, user.id)})

@socketio.on('my broadcast event', namespace='/spotirooms')
def socket_test_message(message):
    sio.emit('my response', {'data': message}, broadcast=True)

@socketio.on('disconnect', namespace='/spotirooms')
def socket_disconnect():
    if RoomUser.query.filter_by(sid=request.sid).first() is not None:
        leave_room(request.sid)
    print "*** Client Disconnected ***"


############################################################
# TEMP METHODS
############################################################

@app.route('/api/logout', methods=['GET', 'POST'])
def logout():
    # remove the username from the session if it's there
    session.pop('username', None)
    return redirect(url_for('index'))

@app.route('/api/users')
@auth.login_required
def users():
    user = model.User.query.get(1)
    return (jsonify({'username': user.username, 'fullname': user.fullname, 'last_seen': user.last_seen}))


############################################################
# Error Handlers
############################################################

@app.errorhandler(400)
def bad_request(e):
    return jsonify(error="Bad Request: %s" % e.description), 400

@app.errorhandler(401)
def bad_request(e):
    return jsonify(error="Unauthorized Access: %s" % e.description), 401

@app.errorhandler(405)
def bad_request(e):
    return jsonify(error="Method Not Allowed: %s" % e.description), 405
