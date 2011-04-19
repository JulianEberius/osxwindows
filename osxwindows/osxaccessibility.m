#include <Python.h>
#include <Carbon/Carbon.h>
#include <Cocoa/Cocoa.h>

static PyObject* copyWindowsInformationForPID(pid_t pid);

static PyObject *
list_windowed_apps(PyObject *self, PyObject *args) {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  NSWorkspace* ws = [NSWorkspace sharedWorkspace];
  NSArray* apps = [ws launchedApplications];
  int app_count = [apps count];
  PyObject* result = PyList_New(app_count);
  int i;
  for (i=0;i<app_count;i++) {
    NSDictionary* app = [apps objectAtIndex:i];
    const char* identifier = [[app objectForKey:@"NSApplicationBundleIdentifier"] UTF8String];
    const char* name = [[app objectForKey:@"NSApplicationName"] UTF8String];
    pid_t pid = [[app objectForKey:@"NSApplicationProcessIdentifier"] intValue];
    PyObject* app_identifier = PyString_FromString(identifier);
    PyObject* app_name = PyString_FromString(name);
    PyObject* window_list = copyWindowsInformationForPID(pid);

    PyObject* app_object = PyTuple_Pack(3,
      app_identifier, 
      app_name,
      window_list);
    PyList_SetItem(result, i, app_object);
    Py_DECREF(app_identifier);
    Py_DECREF(app_name);
    Py_DECREF(window_list);
  }
  [pool release];
  return result;
}

PyMethodDef methods[] = {
  {"list_windowed_apps", list_windowed_apps, METH_VARARGS, "Returns a list of open windows"},
  {NULL, NULL, 0, NULL}
};

PyMODINIT_FUNC 
initosxaccessibility()
{
  (void) Py_InitModule("osxaccessibility", methods);   
}

/*-------------- C-API-Binding ---------------------*/


static bool amIAuthorized ()
{
    if (AXAPIEnabled() != 0) {
        /* Yehaa, all apps are authorized */
        return true;
    }
    /* Bummer, it's not activated, maybe we are trusted */
    if (AXIsProcessTrusted() != 0) {
        /* Good news, we are already trusted */
        return true;
    }
    return false;
}

static char* toCString(CFStringRef str) 
{
  char *result = CFStringGetCStringPtr(str, kCFStringEncodingUTF8);
  if(!result) {
    result = alloca(PATH_MAX);
    if(result)
      CFStringGetCString(str, result, PATH_MAX, kCFStringEncodingUTF8);
    else {
      result = NULL;
    }
  }
  return result;
}


static CFArrayRef windowsForApp(AXUIElementRef app)
{
  CFArrayRef windows;
  AXUIElementCopyAttributeValue(
    app, kAXWindowsAttribute, (CFTypeRef *)&windows
  );
  return windows;
}

static PyObject* fillWindowInformation(CFArrayRef windows, PyObject* windowList)
{
  AXValueRef temp;
  CGSize windowSize;
  CGPoint windowPosition;
  CFStringRef windowTitle;
  AXUIElementRef w;
  int i;
  for (i=0; i<CFArrayGetCount(windows);i++)
  {
    w = (AXUIElementRef)CFArrayGetValueAtIndex(windows,i);
    /* Get the title of the window */
    AXUIElementCopyAttributeValue(
        w, kAXTitleAttribute, (CFTypeRef *)&windowTitle
    );
    /* Get the window size and position */
    AXUIElementCopyAttributeValue(
        w, kAXSizeAttribute, (CFTypeRef *)&temp
    );
    AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);
    CFRelease(temp);
    AXUIElementCopyAttributeValue(
        w, kAXPositionAttribute, (CFTypeRef *)&temp
    );
    AXValueGetValue(temp, kAXValueCGPointType, &windowPosition);
    CFRelease(temp);

    if (windowTitle==NULL)
      windowTitle = CFSTR("");
    PyObject* window_tuple = PyTuple_Pack(5,
      PyString_FromString(toCString(windowTitle)), 
      PyFloat_FromDouble(windowPosition.x),
      PyFloat_FromDouble(windowPosition.y),
      PyFloat_FromDouble(windowSize.width),
      PyFloat_FromDouble(windowSize.height));
    int x;
    for (x=0;x<5;x++)
      Py_DECREF(PyTuple_GetItem(window_tuple,x));

    PyList_SetItem(windowList, i, window_tuple);
  }
}

// TODO: throw errors! just returns [] at the moment
static PyObject* copyWindowsInformationForPID(pid_t pid) 
{
  PyObject* result = NULL;
  AXUIElementRef app = AXUIElementCreateApplication(pid);
  CFArrayRef windows = windowsForApp(app);
  if (windows != NULL) 
  {
    if (CFArrayGetCount(windows) > 0) 
    {
      result = PyList_New(CFArrayGetCount(windows));
      fillWindowInformation(windows, result);
    }
    CFRelease(windows);
  }

  CFRelease(app);
  if (result == NULL)
    result = PyList_New(0);
  return result;
}