#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <dlfcn.h>
#import "RawOverlay.h"

typedef struct {
 int cid;
 uint32_t wid;
 CGContextRef context;
 double scale;
} NDOverlay;
static struct {
 int (*mainConnection)(void);
 CGError (*newRegion)(const CGRect *, CFTypeRef *);
 CFTypeRef (*emptyRegion)(void);
 CGError (*newWindow)(int,int,CFTypeRef,CFTypeRef,int,uint64_t*,float,float,int,uint32_t*,void*);
 CGError (*releaseWindow)(int,uint32_t);
 CGError (*setTags)(int,uint32_t,uint64_t*,int);
 CGError (*setOpacity)(int,uint32_t,bool);
 CGError (*setLevel)(int,uint32_t,int);
 CGError (*setAlpha)(int,uint32_t,float);
 CGError (*setResolution)(int,uint32_t,double);
 CGError (*order)(int,uint32_t,int,uint32_t);
 CGContextRef (*context)(int,uint32_t,CFDictionaryRef);
} api;
static bool loadAPI(void) {
 static bool loaded=false, valid=false;
 if(loaded)return valid;
 loaded=true;
 void *lib=dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",RTLD_LAZY|RTLD_LOCAL);
 if(!lib)return false;
 #define SYM(field,name) api.field=dlsym(lib,name)
 SYM(mainConnection,"SLSMainConnectionID"); SYM(newRegion,"CGSNewRegionWithRect");
 SYM(emptyRegion,"CGRegionCreateEmptyRegion"); SYM(newWindow,"SLSNewWindowWithOpaqueShapeAndContext");
 SYM(releaseWindow,"SLSReleaseWindow"); SYM(setTags,"SLSSetWindowTags");
 SYM(setOpacity,"SLSSetWindowOpacity"); SYM(setLevel,"SLSSetWindowLevel");
 SYM(setAlpha,"SLSSetWindowAlpha"); SYM(setResolution,"SLSSetWindowResolution");
 SYM(order,"SLSOrderWindow"); SYM(context,"SLWindowContextCreate");
 #undef SYM
 valid=api.mainConnection&&api.newRegion&&api.emptyRegion&&api.newWindow&&api.releaseWindow&&api.setTags&&api.setOpacity&&api.setLevel&&api.setAlpha&&api.order&&api.context;
 return valid;
}
void *NDRawOverlayCreate(double x,double y,double scale) {
 if(!loadAPI())return NULL;
 NDOverlay *o=calloc(1,sizeof(NDOverlay));
 o->cid=api.mainConnection();o->scale=scale;
 CGRect rect=CGRectMake(0,0,16,16);
 CFTypeRef region=NULL,empty=api.emptyRegion();
 api.newRegion(&rect,&region);
 if(!region||!empty){if(region)CFRelease(region);if(empty)CFRelease(empty);free(o);return NULL;}
 // Floating, pointer-transparent, sticky, and excluded from window cycling.
 uint64_t tags=(1ULL<<1)|(1ULL<<9)|(1ULL<<11)|(1ULL<<18);
 CGError error=api.newWindow(o->cid,2,region,empty,13|(1<<18),&tags,(float)x,(float)y,64,&o->wid,NULL);
 CFRelease(region);CFRelease(empty);
 if(error||!o->wid){free(o);return NULL;}
 if(api.setTags(o->cid,o->wid,&tags,64) || api.setOpacity(o->cid,o->wid,false) || api.setLevel(o->cid,o->wid,1000)) {
  api.releaseWindow(o->cid,o->wid);free(o);return NULL;
 }
 if(api.setResolution)api.setResolution(o->cid,o->wid,scale);
 o->context=api.context(o->cid,o->wid,NULL);
 if(!o->context){api.releaseWindow(o->cid,o->wid);free(o);return NULL;}
 if(api.setAlpha(o->cid,o->wid,1) || api.order(o->cid,o->wid,1,0)) {
  CGContextRelease(o->context);api.releaseWindow(o->cid,o->wid);free(o);return NULL;
 }
 return o;
}
void NDRawOverlayDraw(void *handle,double red,double green,double blue) {
 NDOverlay *o=handle;if(!o||!o->context)return;
 CGContextRef c=o->context;
 CGContextSaveGState(c);
 CGContextClearRect(c,CGRectMake(0,0,16,16));
 CGContextSetRGBFillColor(c,0,0,0,1);
 double border=1.0/o->scale;
 CGContextFillEllipseInRect(c,CGRectMake(4-border,4-border,8+2*border,8+2*border));
 CGContextSetRGBFillColor(c,red,green,blue,1);
 CGContextFillEllipseInRect(c,CGRectMake(4,4,8,8));
 CGContextRestoreGState(c);
 CGContextFlush(c);
}
unsigned NDRawOverlayWindowID(void *handle) { return handle ? ((NDOverlay *)handle)->wid : 0; }
void NDRawOverlayDestroy(void *handle) {
 NDOverlay *o=handle;if(!o)return;
 api.order(o->cid,o->wid,0,0);
 if(o->context)CGContextRelease(o->context);
 api.releaseWindow(o->cid,o->wid);
 free(o);
}
