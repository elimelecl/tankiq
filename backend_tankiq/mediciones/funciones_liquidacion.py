from math import exp as Exp

def ctlD(API, DF, ABD):
    # On Error Resume Next
    ABD = ABD.upper()
    RD = 141.5 / (API + 131.5)
    d = RD * 999.016
    Temp = DF
    if Temp < -58 or Temp > 302 :
        pass
    psig = 0
    P = psig
    if P < 0 or P > 1500:
        pass
    d60 = d
    if ABD == "A" and (d60 < 610.6 or d60 > 1163.5):
        pass
    if ABD == "B" and (d60 < 610.6 or d60 > 1163.5):
        pass
    if ABD == "D" and (d60 < 800.9 or d60 > 1163.5):
        pass

    tC90 = (Temp - 32) / 1.8
    T = tC90 / 630
    a1 = -0.148759
    a2 = -0.267408
    a3 = 1.08076
    a4 = 1.269056
    a5 = -4.089591
    a6 = -1.871251
    a7 = 7.438081
    a8 = -3.536296
    DTT = (a1 + (a2 + (a3 + (a4 + (a5 + (a6 + (a7 + a8 * T) * T) * T) * T) * T) * T) * T) * T
    TC68 = tC90 - DTT
    TF68 = 1.8 * TC68 + 32

    if ABD == "A":
        k0 = 341.0957
        k1 = 0
        k2 = 0
    elif ABD == "D":
        k0 = 0
        k1 = 0.34878
        k2 = 0
    elif ABD == "B" and d60 < 770.352:
        k0 = 192.4571
        k1 = 0.2438
        k2 = 0
    elif ABD == "B" and d60 < 787.5195:
        k0 = 1489.067
        k1 = 0
        k2 = -0.0018684
    elif ABD == "B" and d60 < 838.3127:
        k0 = 330.301
        k1 = 0
        k2 = 0
    elif ABD == "B" and d60 < 1163.5:
        k0 = 103.872
        k1 = 0.2701
        k2 = 0
    A = 0.01374979547 / 2 * ((k0 / d60 + k1) / d60 + k2)
    B = (2 * k0 + k1 * d60) / (k0 + (k1 + k2 * d60) * d60)
    dr = d60 * (1 + (Exp(A * (1 + 0.8 * A)) - 1) / (1 + A * (1 + 1.6 * A) * B))
    a60 = (k0 / dr + k1) / dr + k2
    DTr = TF68 - 60.0068749
    CTLD = round(Exp(-a60 * DTr * (1 + 0.8 * a60 * (DTr + 0.01374979547))), 5)
    return CTLD


def ctl(ApiF, Temp):
    Pres = 0
    den1 = (141.5 / (ApiF + 131.5)) * 999.016
    den = den1
    if den < 610.6:
        den = 610.6
    if den > 1163.5:
        den = 1163.5
    dens60 = den
    tc90 = (Temp - 32) / 1.8
    t = tc90 / 630
    a1 = -0.148759
    a2 = -0.267408
    a3 = 1.08076
    a4 = 1.269056
    a5 = -4.089591
    a6 = -1.871251
    a7 = 7.438081
    a8 = -3.536296
    DTT = (a1 + (a2 + (a3 + (a4 + (a5 + (a6 + (a7 + a8 * t) * t) * t) * t) * t) * t) * t) * t
    tc68 = tc90 - DTT
    tf68 = 1.8 * tc68 + 32
    k0 = 341.0957
    k1 = 0
    k2 = 0
    Da = 2
    s60 = 0.01374979547
    m = 0
    Ao = (s60 / 2) * ((k1 + k0 / den) * (1 / den) + k2)
    Bo = (2 * k0 + k1 * den) / (k0 + (k1 + k2 * den) * den)
    D = den * (1 + ((Exp(Ao * (1 + 0.8 * Ao)) - 1) / (1 + Ao * (1 + 1.6 * Ao) * Bo)))
    alfa60 = k2 + ((k0 / D) + k1) / D
    while m != 15:
        A = (s60 / 2) * ((((k0 / dens60) + k1) / dens60) + k2)
        B = (2 * k0 + k1 * dens60) / (k0 + (k1 + k2 * dens60) * dens60)
        de = dens60 * (1 + ((Exp(A * (1 + 0.8 * A)) - 1) / (1 + A * (1 + 1.6 * A) * B)))
        DT = tf68 - 60.0068749
        CTLc = Exp(-alfa60 * DT * (1 + 0.8 * alfa60 * (DT + s60)))
        Fp = Exp(-1.9947 + 0.00013427 * tf68 + ((793920 + 2326 * tf68) / de ** 2))
        CPL2 = 1 / (1 - Fp * Pres * 10 ** -5)
        CTPL2 = CTLc * CPL2
        CTPL2 = round(CTPL2, 5)
        dt2 = Temp - 60
        x = dens60 * CTPL2
        spo = dens60 - x
        e = (den / (CTLc * CPL2)) - dens60
        Dtm = 2 * alfa60 * dt2 * (1 + 1.6 * alfa60 * dt2)
        Dp = (Da * CPL2 * Pres * Fp * (7.9392 + 0.02326 * Temp)) / (dens60 ** 2)
        Ddens60 = e / (1 + Dtm + Dp)
        if (dens60 + Ddens60) < 610.6:
            Ddens60 = 610.6 - dens60
        if (dens60 + Ddens60) > 1163.5:
            Ddens60 = 1163.5 - dens60
        if abs(spo) < 0.000001:
           break
        else:
            dens60 = dens60 + Ddens60
        m = m + 1
    d60 = dens60
    DT = tf68 - 60.0068749
    CTL = round(Exp(-alfa60 * DT * (1 + 0.8 * alfa60 * (DT + s60))), 5)
    if d60 < 610.6:
        CTL = "Out"
    if d60 > 1163.5:
        CTL = "Out"
    if Temp < -58:
        CTL = "Temp low"
    if Temp > 302:
        CTL = "Temp High"
    if den1 < 470.5:
        CTL = "Api High"
    if den1 > 1201.8:
        CTL = "Api Low"
    return CTL





