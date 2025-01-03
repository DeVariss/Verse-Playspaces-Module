playspaces<public> := module:
    using { core.containers }
    using { core.players }
    using { /Fortnite.com/Playspaces }
    using { /Verse.org/Concurrency }
    using { /Verse.org/Simulation }

    ConstructPlayerOnboardingRoutine<public><constructor>(Playspace: fort_playspace) := player_onboarding:
        Playspace := Playspace

    player_onboarding<public> := class<internal><final>:
        Playspace: fort_playspace

        LookupCapacity<private>: int = 256
        PlayerOnboardedEvent<private>: event(player_onboarding_result) = event(player_onboarding_result){}

        var PlayerRemovedSignalableLookup<private>: [player]signalable(tuple()) = map{}

        StartOnboardingPlayers<public>(): void =
            spawn:
                AwaitAddedPlayers(Playspace.PlayerAddedEvent())
            spawn:
                AwaitRemovedPlayers(Playspace.PlayerRemovedEvent())
            for (Player : Playspace.GetPlayers()):
                Player.StartOnboarding()

        AwaitPlayerOnboarded<public>()<suspends>: player_onboarding_result = PlayerOnboardedEvent.Await()

        AwaitAddedPlayers<private>(PlayerAddedEvent: listenable(player))<suspends>: void = loop:
            AddedPlayer := PlayerAddedEvent.Await()
            AddedPlayer.StartOnboarding()

        AwaitRemovedPlayers<private>(PlayerRemovedEvent: listenable(player))<suspends>: void = loop:
            RemovedPlayer := PlayerRemovedEvent.Await()
            PlayerRemovedSignalable := PlayerRemovedSignalableLookup[RemovedPlayer] or GrabErr()
            PlayerRemovedSignalable.Signal()

        (OnboardingPlayer: player).StartOnboarding<private>(): void =
            PlayerLeaveEvent := event(void){}
            OnboardingPlayer.PutOnLookup(PlayerLeaveEvent)
            spawn:
                OnboardingPlayer.HandleOnboarding(PlayerLeaveEvent)

        (OnboardingPlayer: player).HandleOnboarding<private>(PlayerRemovedAwaitable: awaitable(void))<suspends>: void = race:
            OnboardingPlayer.SignalWhenActive(PlayerRemovedAwaitable)
            PlayerRemovedAwaitable.Await()

        (OnboardingPlayer: player).SignalWhenActive<private>(PlayerRemovedAwaitable: awaitable(void))<suspends>: void = loop:
            if (OnboardingPlayer.IsActive[]):
                OnboardingResult := player_onboarding_result{Player := OnboardingPlayer, PlayerRemovedEvent := PlayerRemovedAwaitable}
                PlayerOnboardedEvent.Signal(OnboardingResult)
                break
            Sleep(0.0)

        (OnboardingPlayer: player).PutOnLookup<private>(PlayerLeaveSignalable: signalable(void)): void =
            if (PlayerRemovedSignalableLookup.Length >= LookupCapacity):
                CleanLookup()
            (set PlayerRemovedSignalableLookup[OnboardingPlayer] = PlayerLeaveSignalable) or PutErr()

        CleanLookup<private>(): void =
            var NewLookup: [player]signalable(tuple()) = map{}
            for (Player : Playspace.GetPlayers()):
                PlayerRemovedSignalable := PlayerRemovedSignalableLookup[Player] or GrabErr()
                (set NewLookup[Player] = PlayerRemovedSignalable) or PutErr()
            set PlayerRemovedSignalableLookup = NewLookup
    
    PutErr()<computes>: false = Err("Failed to put player and event onto lookup.")

    GrabErr()<computes>: false = Err("Failed to grab players leave event.")

    player_onboarding_result<public> := struct<internal>:
        Player: player
        PlayerRemovedEvent: awaitable()
