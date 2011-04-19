import osxaccessibility

class App(object):
    """Represents an OSX-Application
    Mainly a container for windows"""
    def __init__(self, identifier, name, windows):
        super(App, self).__init__()
        self.identifier = identifier
        self.name = name
        self.windows = windows

class Layout(object):
    """A window layout for one space"""
    def __init__(self):
        super(Layout, self).__init__()

class Window(object):
    """represents a OSX-Window, with position, size and title"""
    def __init__(self, position, size, title):
        super(Window, self).__init__()
        self.position = position
        self.size = size
        self.title = title
        
def get_windowed_apps():
    windowed_apps_raw = osxaccessibility.list_windowed_apps()
    apps = []
    for identifier, name, windows_raw in windowed_apps_raw:
        windows = [Window((w[1], w[2]), (w[3], w[4]), w[0])
                    for w in windows_raw]
        app = App(identifier, name, windows)
        apps.append(app)
    return apps

if __name__ == '__main__':
    apps = get_windowed_apps()
    for a in apps:
        print a.name
        for w in a.windows:
            print "\t", w.title
