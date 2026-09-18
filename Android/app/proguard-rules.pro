# Gold Rush app-specific R8 configuration.
# Library consumer rules cover Compose, DataStore, Billing, and Play Review.
#
# Google Mobile Ads transitively brings an older Room runtime through WorkManager.
# Modern R8 full mode no longer implicitly preserves Room-generated no-arg
# constructors, but Room instantiates those implementations reflectively.
# Mirror the upstream AndroidX Room fix for this constructor.
-keep class * extends androidx.room.RoomDatabase { void <init>(); }
