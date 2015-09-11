if __name__ == '__main__':
    import eventlet
    eventlet.monkey_patch()

    from app import app, socketio
    from flask.ext.socketio import SocketIO, emit
    #app.run(host='0.0.0.0', debug=True)
    app.debug = True
    socketio.run(app, host='0.0.0.0')
