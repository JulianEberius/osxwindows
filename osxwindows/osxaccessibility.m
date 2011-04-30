#include <Python.h>
#include <Carbon/Carbon.h>
#include <Cocoa/Cocoa.h>

typedef struct {
  PyObject_HEAD
  /* Type-specific fields go here. */
  AXUIElementRef window;
} WindowReference;

static void
WindowReference_dealloc(WindowReference* self)
{
    CFRelease(self->window);
    self->ob_type->tp_free((PyObject*)self);
}

static PyTypeObject WindowReferenceType = {
  PyObject_HEAD_INIT(NULL)
  0,        /* ob_size        */
  "osxaccessibility.WindowReference",    /* tp_name        */
  sizeof(WindowReference),  /* tp_basicsize   */
  0,        /* tp_itemsize    */
  (destructor)WindowReference_dealloc,        /* tp_dealloc     */
  0,        /* tp_print       */
  0,        /* tp_getattr     */
  0,        /* tp_setattr     */
  0,        /* tp_compare     */
  0,        /* tp_repr        */
  0,        /* tp_as_number   */
  0,        /* tp_as_sequence */
  0,        /* tp_as_mapping  */
  0,        /* tp_hash        */
  0,        /* tp_call        */
  0,        /* tp_str         */
  0,        /* tp_getattro    */
  0,        /* tp_setattro    */
  0,        /* tp_as_buffer   */
  Py_TPFLAGS_DEFAULT,   /* tp_flags       */
  "Stores a accessibility API reference to a window.", /* tp_doc         */
};

static PyObject* authorized(PyObject *self, PyObject *args)
{
    if (AXAPIEnabled() != 0) {
        /* Yehaa, all apps are authorized */
        Py_RETURN_TRUE;
    }
    /* Bummer, it's not activated, maybe we are trusted */
    if (AXIsProcessTrusted() != 0) {
        /* Good news, we are already trusted */
        Py_RETURN_TRUE;
    }
    Py_RETURN_FALSE;
}

static PyObject* copyWindowsInformationForPID(pid_t pid);

static PyObject *
windowed_apps_raw(PyObject *self, PyObject *args) {
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

static PyObject *
move_window_by(PyObject *self, PyObject *args)
{
  PyObject* window;
  int x,y;
  PyArg_ParseTuple(args, "Oii", &window, &x, &y);

  AXUIElementRef windowRef = ((WindowReference*)window)->window;

  AXValueRef temp;
  CGPoint windowPosition;

  AXUIElementCopyAttributeValue(
      windowRef, kAXPositionAttribute, (CFTypeRef *)&temp
  );
  AXValueGetValue(temp, kAXValueCGPointType, &windowPosition);
  CFRelease(temp);

  windowPosition.y += y;
  windowPosition.x += x;
  temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
  AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, temp);
  CFRelease(temp);

  Py_RETURN_TRUE;
}

static PyObject *
move_window_to(PyObject *self, PyObject *args)
{
  PyObject* window;
  int x,y;
  PyArg_ParseTuple(args, "Oii", &window, &x, &y);

  AXUIElementRef windowRef = ((WindowReference*)window)->window;
  AXValueRef temp;
  CGPoint windowPosition;

  windowPosition = CGPointMake(x,y);
  temp = AXValueCreate(kAXValueCGPointType, &windowPosition);
  AXUIElementSetAttributeValue(windowRef, kAXPositionAttribute, temp);
  CFRelease(temp);

  Py_RETURN_TRUE;
}

static PyObject *
resize_window_by(PyObject *self, PyObject *args)
{
  PyObject* window;
  int width,height;
  PyArg_ParseTuple(args, "Oii", &window, &width, &height);

  AXUIElementRef windowRef = ((WindowReference*)window)->window;

  AXValueRef temp;
  CGSize windowSize;

  AXUIElementCopyAttributeValue(
      windowRef, kAXSizeAttribute, (CFTypeRef *)&temp
  );
  AXValueGetValue(temp, kAXValueCGSizeType, &windowSize);
  CFRelease(temp);

  windowSize.width += width;
  windowSize.height += height;
  temp = AXValueCreate(kAXValueCGSizeType, &windowSize);
  AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, temp);
  CFRelease(temp);

  Py_RETURN_TRUE;
}

static PyObject *
resize_window_to(PyObject *self, PyObject *args)
{
  PyObject* window;
  int width,height;
  PyArg_ParseTuple(args, "Oii", &window, &width, &height);

  AXUIElementRef windowRef = ((WindowReference*)window)->window;

  AXValueRef temp;
  CGSize windowSize;

  windowSize = CGSizeMake(width,height);
  temp = AXValueCreate(kAXValueCGSizeType, &windowSize);
  AXUIElementSetAttributeValue(windowRef, kAXSizeAttribute, temp);
  CFRelease(temp);

  Py_RETURN_TRUE;
}

static PyObject *
set_window_alpha(PyObject *self, PyObject *args)
{
  PyObject* window;
  float alpha;
  PyArg_ParseTuple(args, "Of", &window, &alpha);
  AXUIElementRef windowRef = ((WindowReference*)window)->window;

  AXUIElementSetAttributeValue(windowRef, CFSTR("AXAlpha"), CFNumberCreate(NULL, kCFNumberFloat32Type, &alpha));

  Py_RETURN_TRUE;
}

static PyObject *
screen_size(PyObject *self, PyObject *args)
{
    NSRect screen_size = [[NSScreen mainScreen] frame];
    PyObject* py_screen_size = PyTuple_Pack(2,
            Py_BuildValue("i",(int)screen_size.size.width),
            Py_BuildValue("i",(int)screen_size.size.height)
            );
    return py_screen_size;
}

static PyMethodDef methods[] = {
  {"authorized", authorized, METH_VARARGS, "Checks whether the app is allowed to access the accessibility API."},
  {"windowed_apps_raw", windowed_apps_raw, METH_VARARGS, "Returns a list of open windows"},
  {"move_window_by", move_window_by, METH_VARARGS, "Moves a window by x and y pixel."},
  {"move_window_to", move_window_to, METH_VARARGS, "Moves a window to x and y pixel."},
  {"resize_window_by",resize_window_by, METH_VARARGS, "Resizes a window by x and y pixel."},
  {"resize_window_to", resize_window_to, METH_VARARGS, "Resizes a window to x and y pixel."},
  {"screen_size", screen_size, METH_VARARGS, "Returns the screen size as tuple (width,height)."},
  {"set_window_alpha", set_window_alpha, METH_VARARGS, "Sets the windows alpha value. Will work only in conjunction with AweSX's ScriptingAddition, as Alpha is usually not exposed by the Accessibility API."},
  {NULL, NULL, 0, NULL}
};

PyMODINIT_FUNC
initosxaccessibility(void)
{
  PyObject* m;

  WindowReferenceType.tp_new = PyType_GenericNew;
  if (PyType_Ready(&WindowReferenceType) < 0)
    return;

  m = Py_InitModule("osxaccessibility", methods);
  if (m == NULL)
    return;

  Py_INCREF(&WindowReferenceType);
  PyModule_AddObject(m, "WindowReference", (PyObject *)&WindowReferenceType);

}

/*-------------- Utility Functions ---------------------*/

static char* toCString(CFStringRef str)
{
  char *result = (char*)CFStringGetCStringPtr(str, kCFStringEncodingUTF8);
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

/*-------------- C-API-Binding ---------------------*/

static CFArrayRef windowsForApp(AXUIElementRef app)
{
  CFArrayRef windows;
  AXUIElementCopyAttributeValue(
    app, kAXWindowsAttribute, (CFTypeRef *)&windows
  );
  return windows;
}

static void fillWindowInformation(CFArrayRef windows, PyObject* windowList)
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

    WindowReference* windowRef = (WindowReference*)PyObject_CallFunction(
      (PyObject*)&WindowReferenceType, NULL);
    windowRef->window = w;
    CFRetain(w);

    if (windowTitle==NULL)
      windowTitle = CFSTR("");
    PyObject* window_tuple = PyTuple_Pack(6,
      PyString_FromString(toCString(windowTitle)),
      PyFloat_FromDouble(windowPosition.x),
      PyFloat_FromDouble(windowPosition.y),
      PyFloat_FromDouble(windowSize.width),
      PyFloat_FromDouble(windowSize.height),
      windowRef);
    int x;
    for (x=0;x<6;x++)
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
