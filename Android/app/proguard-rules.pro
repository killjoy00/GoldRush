# Gold Rush app-specific R8 configuration.
# Library consumer rules cover Compose, DataStore, Billing, and Play Review.
#
# WorkManager currently brings an older Room runtime whose consumer rule does
# not preserve the generated RoomDatabase implementation constructor under
# modern R8 full mode. Keep the no-arg constructor used by Room reflection.
-keep class * extends androidx.room.RoomDatabase { void <init>(); }
