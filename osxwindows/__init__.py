import osxaccessibility

class App(object):
    """Represents an OSX-Application
    Mainly a container for windows"""
    def __init__(self, identifier, name, windows):
        super(App, self).__init__()
        self.identifier = identifier
        self.name = name
        self.windows = windows

class Window(object):
    """represents a OSX-Window, with position, size and title"""
    def __init__(self, position, size, title, window_ref):
        super(Window, self).__init__()
        self.x = position[0]
        self.y = position[1]
        self.width = size[0]
        self.height = size[1]
        self.title = title
        self._window_ref = window_ref

    def move_by(self,x,y):
         osxaccessibility.move_window_by(self._window_ref,x,y)
         self.x += x
         self.y += y
    def move_to(self,x,y):
         osxaccessibility.move_window_to(self._window_ref,x,y)
         self.x = x
         self.y = y
    def resize_by(self,width,height):
         osxaccessibility.resize_window_by(self._window_ref,width,height)
         self.width += width
         self.height += height
    def resize_to(self,width,height):
         osxaccessibility.resize_window_to(self._window_ref,width,height)
         self.width = width
         self.height = height
    def set_alpha(self, alpha):
        ''' will only work in conjunction with the AweSX ScriptingAddition, as Alpha is usually not
        exposed by the Accessiblity API'''
        osxaccessibility.set_window_alpha(self._window_ref, alpha)


def windowed_apps():
    """ returns all apps that would be returned by [NSWorkspace launchedApplicatios],
    e.g., Apps on the Dock """
    windowed_apps_raw = osxaccessibility.windowed_apps_raw()
    apps = []
    for identifier, name, windows_raw in windowed_apps_raw:
        windows = [Window((w[1], w[2]), (w[3], w[4]), w[0], w[5])
                    for w in windows_raw]
        app = App(identifier, name, windows)
        apps.append(app)
    return apps

def screen_size():
    """ return the current screen's size as a (width,height) tuple """
    return osxaccessibility.screen_size()

if __name__ == '__main__':
    apps = windowed_apps()
    for a in apps:
        print a.name
        for w in a.windows:
            print "\t", w.title
