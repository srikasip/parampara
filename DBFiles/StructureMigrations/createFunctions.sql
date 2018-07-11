CREATE OR REPLACE FUNCTION getUID(ident text, tok text)
RETURNS text AS $$
DECLARE 
  _uid_ text;
BEGIN
  SELECT uid FROM identities 
    WHERE identity = ident 
      AND token = tok
      INTO _uid_;

  RETURN _uid_;

END $$ LANGUAGE PLPGSQL;


CREATE OR REPLACE FUNCTION getToken() RETURNS text AS $$
DECLARE
    new_token text;
BEGIN
    SELECT array_to_string(ARRAY(SELECT chr((48 + round(random() * 59)) :: integer) 
                          FROM generate_series(1,15)), '') into new_token;

    
    RETURN new_token;
END $$ LANGUAGE PLPGSQL VOLATILE;

CREATE OR REPLACE FUNCTION make_uid() RETURNS text AS $$
DECLARE
    new_uid text;
    done bool;
BEGIN
    done := false;
    WHILE NOT done LOOP
        SELECT array_to_string(ARRAY(SELECT chr((48 + round(random() * 59)) :: integer) 
                          FROM generate_series(1,15)), '') INTO new_uid;

        done := NOT exists(SELECT 1 FROM identities WHERE identity=new_uid);
    END LOOP;
    RETURN new_uid;
END $$ LANGUAGE PLPGSQL VOLATILE;



CREATE OR REPLACE FUNCTION getUniqueValue(n bigint) RETURNS text AS $$
DECLARE
 alphabet text:='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
 base int:=length(alphabet); 
 _n bigint:=abs(n);
 output text:='';
BEGIN
 LOOP
   output := output || substr(alphabet, 1+(_n%base)::int, 1);
   _n := _n / base; 
   EXIT WHEN _n=0;
 END LOOP;
 RETURN output;
END $$ LANGUAGE plpgsql IMMUTABLE STRICT;


CREATE OR REPLACE FUNCTION pseudo_encrypt(VALUE bigint) returns int AS $$
DECLARE
l1 int;
l2 int;
r1 int;
r2 int;
i int:=0;
BEGIN
 l1:= (VALUE >> 16) & 65535;
 r1:= VALUE & 65535;
 WHILE i < 3 LOOP
   l2 := r1;
   r2 := l1 # ((((1366 * r1 + 150889) % 714025) / 714025.0) * 32767)::int;
   l1 := l2;
   r1 := r2;
   i := i + 1;
 END LOOP;
 RETURN ((r1 << 16) + l1);
END;
$$ LANGUAGE plpgsql strict immutable;



CREATE OR REPLACE FUNCTION insertdiagnoses(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    INSERT INTO diagnoses (name) VALUES (val) RETURNING id INTO _itemID_;
    RETURN _itemID_;
  END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION insertorGetdiagnoses(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    SELECT min(id) INTO _itemID_ From diagnoses WHERE name = val;

    SELECT (CASE WHEN _itemID_ > 0 
    THEN 
      _itemID_
    ELSE
      insertdiagnoses(val)
    END) INTO _itemID_;

    RETURN _itemID_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION insertinsurances(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    INSERT INTO insurances (name) VALUES (val) RETURNING id INTO _itemID_;
    RETURN _itemID_;
  END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION insertorGetinsurances(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    SELECT min(id) INTO _itemID_ From insurances WHERE name = val;

    SELECT (CASE WHEN _itemID_ > 0 
    THEN 
      _itemID_
    ELSE
      insertinsurances(val)
    END) INTO _itemID_;

    RETURN _itemID_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION insertpractices(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    INSERT INTO practices (name) VALUES (val) RETURNING id INTO _itemID_;
    RETURN _itemID_;
  END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION insertorGetpractices(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    SELECT min(id) INTO _itemID_ From practices WHERE name = val;

    SELECT (CASE WHEN _itemID_ > 0 
    THEN 
      _itemID_
    ELSE
      insertpractices(val)
    END) INTO _itemID_;

    RETURN _itemID_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION insertrefdocs(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    INSERT INTO refdocs (name) VALUES (val) RETURNING id INTO _itemID_;
    RETURN _itemID_;
  END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION insertorGetrefdocs(val varchar(100))
  RETURNS integer as $$
  DECLARE _itemID_ integer;
  BEGIN
    SELECT min(id) INTO _itemID_ From refdocs WHERE name = val;

    SELECT (CASE WHEN _itemID_ > 0 
    THEN 
      _itemID_
    ELSE
      insertrefdocs(val)
    END) INTO _itemID_;

    RETURN _itemID_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION getPatientFromID(_patient_id integer)
RETURNS json as $$
DECLARE json_output json;
BEGIN
  SELECT array_to_json(array_agg(row_to_json(t)))
  FROM
    (
      SELECT p.id as "Id", p.name as "Name", to_char(p.clinicdate, 'Mon DD, YYYY') as "ClinicDate", p.issurgical as "IsSurgical", p.appscore as "AppScore", p.complscore as "ComplexityScore", 
        ref.name as "Referring_Doc", diag.name as "Diagnosis", ins.name as "Insurance", ins.is_medicaid as "IsMedicaid",
        p.isdirect as "IsDirect", p.wasscreened as "WasScreened", p.screendate as "ScreenDate", p.valuescore as "ValueScore", p.location as "Location", '' as "Practice"
        FROM 
          patients as p
          Join refDocs as ref 
            On p.refdoc_id = ref.id
          Left Join diagnoses as diag
            On p.diagnosis_id = diag.id
          Left JOIN insurances as ins 
            ON p.insurance_id = ins.id
        WHERE
          p.id = _patient_id
        ORDER BY p.clinicdate desc
    ) t INTO json_output;

    RETURN json_output;




END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION getDocPatients(_userID integer)
RETURNS json as $$
DECLARE json_output json;
BEGIN
  SELECT array_to_json(array_agg(row_to_json(t)))
  FROM
    (
      SELECT p.id, p.name, to_char(p.clinicdate, 'Mon DD, YYYY') as visit_date, p.issurgical, p.appscore, p.complscore, 
        ref.name as docName, diag.name as diagnosis, ins.name as insurance
        FROM 
          patients as p
          Join refDocs as ref 
            On p.refdoc_id = ref.id
          Join diagnoses as diag
            On p.diagnosis_id = diag.id
          JOIN insurances as ins 
            ON p.insurance_id = ins.id
        WHERE
          p.user_id = _userID
        ORDER BY p.clinicdate desc
    ) t INTO json_output;

    RETURN json_output;
END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION createPatient(_userID text, _name varchar(100), _refDoc varchar(100), _visitDate date, _diagnosis varchar(100), _insurance varchar(100), _appScore numeric, _complScore numeric, _isSurgical boolean)
  RETURNS integer as $$
  DECLARE _patient_id integer;
  DECLARE _refDoc_id integer;
  DECLARE _diagnosis_id integer;
  DECLARE _insurance_id integer;
  BEGIN
    Select insertorGetrefdocs(_refDoc) into _refDoc_id;


    Select CASE WHEN _diagnosis is not null THEN
      insertorGetdiagnoses(lower(_diagnosis)) 
      ELSE NULL END
      into _diagnosis_id;

    Select CASE WHEN _insurance is not null THEN
      insertorGetinsurances(upper(_insurance)) 
      ELSE NULL END
      into _insurance_id;

    INSERT INTO patients(user_id, name, clinicdate, refdoc_id, diagnosis_id, issurgical,appscore,complscore, insurance_id)
    VALUES (_userID, _name, _visitDate, _refDoc_id, _diagnosis_id, _isSurgical, _appScore, _complScore, _insurance_id)
    RETURNING id into _patient_id;

    RETURN _patient_id;

  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION editPatient(_userID text, _pID INTEGER, _name varchar(100), _refDoc varchar(100), _visitDate date, _diagnosis varchar(100), _insurance varchar(100), _appScore numeric, _complScore numeric, _isSurgical boolean)
  RETURNS INTEGER as $$
  DECLARE _patient_id integer;
  DECLARE _refDoc_id integer;
  DECLARE _diagnosis_id integer;
  DECLARE _insurance_id integer;

  BEGIN
    Select insertorGetrefdocs(_refDoc) into _refDoc_id;


    Select CASE WHEN _diagnosis is not null THEN
      insertorGetdiagnoses(lower(_diagnosis)) 
      ELSE NULL END
      into _diagnosis_id;

    Select CASE WHEN _insurance is not null THEN
      insertorGetinsurances(upper(_insurance)) 
      ELSE NULL END
      into _insurance_id;

    UPDATE patients SET 
    name = _name, 
    clinicdate = _visitDate, 
    refdoc_id = _refDoc_id, 
    diagnosis_id = _diagnosis_id, 
    issurgical = _isSurgical,
    appscore = _appScore,
    complscore = _complScore, 
    insurance_id = _insurance_id
    Where id = _pID;

    RETURN _pID;

  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION checkUserName(username varchar(100))
  RETURNS boolean as $$
  DECLARE _isUnique_ boolean;

  BEGIN
    _isUnique_ := NOT exists(SELECT 1 FROM usernames WHERE name=username);

    RETURN _isUnique_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION createNewUser(username varchar(100), email varchar(100), password varchar(100), spec varchar(100), nam varchar(100), zippy varchar(10))
  RETURNS json as $$
  DECLARE _user_dats_ RECORD;
  DECLARE json_output json;
  DECLARE _is_new_ boolean;

  BEGIN
    Select CASE WHEN NOT checkUserName(email) THEN false
           WHEN NOT checkUserName(username) THEN false
           ELSE true 
           END INTO _is_new_;

    IF _is_new_ THEN
      INSERT INTO usernames (name) VALUES (email), (username);

      INSERT INTO identities(idx, uid, identity, token, created_at, uname, pwd) 
            VALUES (DEFAULT,DEFAULT,DEFAULT,DEFAULT,DEFAULT, username, password)
            RETURNING uid, identity, token INTO _user_dats_;
      INSERT INTO notifs(uid, email_id)
            VALUES (_user_dats_.uid, email);

      INSERT INTO users (uid, specialty, email_id, name, zip)
            VALUES (_user_dats_.uid, spec, email, nam, zippy);
    ELSE 
      Select '' as uid,'' as identity, '' as token INTO _user_dats_;
    END IF;

    SELECT row_to_json(t)
    FROM
      (
        select _user_dats_.uid as uid, _user_dats_.identity as identity, _user_dats_.token as token
      ) t INTO json_output;

    RETURN json_output;
  END $$ language 'plpgsql';

CREATE OR REPLACE FUNCTION updateToken(sendentity text, tok text)
  RETURNS text as $$
  DECLARE _new_token_ text;
  BEGIN

  Select getToken() INTO _new_token_;

  UPDATE identities
  SET old_token = token,
      token = _new_token_
  WHERE identity = sendentity and token = tok;

  RETURN _new_token_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION updateIdentity(sendentity text, tok text)
  RETURNS text as $$
  DECLARE _new_id_ text;

  BEGIN

    Select make_uid() INTO _new_id_;
    
    UPDATE identities
    SET old_identity = identity,
        identity = _new_id_
    WHERE identity = sendentity and token = tok;

    RETURN _new_id_;
  END $$ language 'plpgsql';


CREATE OR REPLACE FUNCTION login(username text, password text)
  RETURNS json as $$
  DECLARE _user_id_ RECORD;
  DECLARE json_output json;
  
  BEGIN
    select uid, identity, token FROM identities where uname = username and pwd = password
    INTO _user_id_;

    SELECT row_to_json(t)
    FROM
      (
        select uid as uid, identity as identity, token as token FROM identities where uname = username and pwd = password
      ) t INTO json_output;

    RETURN json_output;

  END $$ language 'plpgsql';