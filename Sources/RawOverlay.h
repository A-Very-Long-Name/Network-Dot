#ifndef NETWORK_DOT_RAW_OVERLAY_H
#define NETWORK_DOT_RAW_OVERLAY_H
void *NDRawOverlayCreate(double x, double y, double scale);
void NDRawOverlayDraw(void *overlay, double red, double green, double blue);
unsigned NDRawOverlayWindowID(void *overlay);
void NDRawOverlayDestroy(void *overlay);
#endif
