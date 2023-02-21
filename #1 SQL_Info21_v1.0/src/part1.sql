DROP TABLE IF EXISTS P2P;
DROP TABLE IF EXISTS Recommendations;
DROP TABLE IF EXISTS XP;
DROP TABLE IF EXISTS TimeTracking;
DROP TABLE IF EXISTS Recommendations;
DROP TABLE IF EXISTS Friends;
DROP TABLE IF EXISTS TransferredPoints;
DROP TABLE IF EXISTS Verter;
DROP TABLE IF EXISTS Checks;
DROP TABLE IF EXISTS Tasks;
DROP TABLE IF EXISTS Peers;
DROP TYPE IF EXISTS CheckStatus;
create table Peers
(
    Nickname varchar not null primary key,
    Birthday date    not null
);
create table Tasks
(
    Title      varchar not null primary key,
    ParentTask varchar default null,
    MaxXP      integer not null
);
create table Checks
(
    id   bigint primary key,
    peer varchar not null,
    task varchar not null,
    Date date    not null,
    constraint fk_checks_peers_id foreign key (peer) references Peers (Nickname),
    constraint fk_checks_tasks_id foreign key (task) references Tasks (Title)
);
CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');
create table P2P
(
    id           bigint primary key,
    Check_id     bigint      not null,
    CheckingPeer varchar     not null,
    State        CheckStatus not null,
    Time         time        not null,
    constraint fk_p2p_chesks_id foreign key (Check_id) references Checks (id),
    constraint fk_p2p_peers_id foreign key (CheckingPeer) references Peers (Nickname)
);
create table Verter
(
    id       bigint primary key,
    Check_id bigint      not null,
    State    CheckStatus not null,
    Time     time        not null,
    constraint fk_verter_check_id foreign key (Check_id) references Checks (id)
);
create table TransferredPoints
(
    id           bigint primary key,
    CheckingPeer varchar not null,
    CheckedPeer  varchar not null,
    PointsAmount integer not null,
    constraint fk_transferredpoints_checkingpeer_peers_id foreign key (CheckingPeer) references Peers (Nickname),
    constraint fk_transferredpoints_checkedpeer_peers_id foreign key (CheckedPeer) references Peers (Nickname)
);
create table Friends
(
    id    bigint primary key,
    Peer1 varchar not null,
    Peer2 varchar not null,
    constraint fk_friends_peer1_peers_id foreign key (Peer1) references Peers (Nickname),
    constraint fk_friends_peer2_peers_id foreign key (Peer2) references Peers (Nickname)
);
create table Recommendations
(
    id             bigint primary key,
    Peer           varchar not null,
    RecomendedPeer varchar not null,
    constraint fk_friends_peer_peers_id foreign key (Peer) references Peers (Nickname),
    constraint fk_friends_recomendedpeer_peers_id foreign key (RecomendedPeer) references Peers (Nickname)
);
create table XP
(
    id       bigint primary key,
    Check_id bigint not null,
    XPAmount integer,
    constraint fk_xp_check_id foreign key (Check_id) references Checks (id)
);
create table TimeTracking
(
    id    bigint primary key,
    Peer  varchar   not null,
    Date  date      not null,
    Time  time not null,
    State integer   not null,
    constraint fk_timetracking_peers_id foreign key (Peer) references Peers (Nickname)
);

CREATE OR REPLACE PROCEDURE export_to_csv(del CHARACTER, path TEXT)
    LANGUAGE plpgsql
AS
$$
DECLARE
    statement TEXT;
    tables    RECORD;
BEGIN
    FOR tables IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_name NOT LIKE ('pg_%')
          AND table_name NOT LIKE ('sql_%')
        LOOP
            statement := 'COPY ' || tables.table_name || ' TO ''' ||
                         path || '/' || tables.table_name || '.csv' ||
                         ''' WITH DELIMITER ''' || del || '''CSV;';
            EXECUTE statement;
        END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE import_from_csv(del CHARACTER, path TEXT)
    LANGUAGE plpgsql
AS
$$
DECLARE
    statement TEXT;
    tables    RECORD;
BEGIN
    statement := 'COPY peers FROM ''' ||
                 path || '/peers.csv' ||
                 ''' WITH DELIMITER ''' || del || '''CSV;';
    EXECUTE statement;
    statement := 'COPY tasks FROM ''' ||
                 path || '/tasks.csv' ||
                 ''' WITH DELIMITER ''' || del || '''CSV;';
    EXECUTE statement;
    statement := 'COPY checks FROM ''' ||
                 path || '/checks.csv' ||
                 ''' WITH DELIMITER ''' || del || '''CSV;';
    EXECUTE statement;
    FOR tables IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_type = 'BASE TABLE'
          AND table_name NOT LIKE ('pg_%')
          AND table_name NOT LIKE ('sql_%')
          AND table_name NOT LIKE ('peers')
          AND table_name NOT LIKE ('checks')
          AND table_name NOT LIKE ('tasks')

        LOOP
            statement := 'COPY ' || tables.table_name || ' FROM ''' ||
                         path || '/' || tables.table_name || '.csv' ||
                         ''' WITH DELIMITER ''' || del || '''CSV;';
            EXECUTE statement;
        END LOOP;
END;
$$;