architecture CFBank_arq of CFBank_2or_64CH is
        --Ideal cutoff: 23257.3762Hz - Real cutoff: 23256.1566Hz - Error: 0.0052%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7CB1",
            SPIKES_DIV_OUT  => x"7CB1",
            SPIKES_DIV_BPF  => x"2025",
Filter_1
        --Ideal cutoff: 20810.6020Hz - Real cutoff: 20809.6739Hz - Error: 0.0045%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"6F93",
            SPIKES_DIV_OUT  => x"6F93",
            SPIKES_DIV_BPF  => x"2025",
Filter_2
        --Ideal cutoff: 18621.2388Hz - Real cutoff: 18620.6135Hz - Error: 0.0034%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"77CE",
            SPIKES_DIV_OUT  => x"77CE",
            SPIKES_DIV_BPF  => x"2025",
Filter_3
        --Ideal cutoff: 16662.2058Hz - Real cutoff: 16661.4117Hz - Error: 0.0048%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6B33",
            SPIKES_DIV_OUT  => x"6B33",
            SPIKES_DIV_BPF  => x"2025",
Filter_4
        --Ideal cutoff: 14909.2714Hz - Real cutoff: 14908.4816Hz - Error: 0.0053%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7FE5",
            SPIKES_DIV_OUT  => x"7FE5",
            SPIKES_DIV_BPF  => x"2025",
Filter_5
        --Ideal cutoff: 13340.7531Hz - Real cutoff: 13340.2701Hz - Error: 0.0036%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7271",
            SPIKES_DIV_OUT  => x"7271",
            SPIKES_DIV_BPF  => x"2025",
Filter_6
        --Ideal cutoff: 11937.2495Hz - Real cutoff: 11936.4386Hz - Error: 0.0068%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6666",
            SPIKES_DIV_OUT  => x"6666",
            SPIKES_DIV_BPF  => x"2025",
Filter_7
        --Ideal cutoff: 10681.4005Hz - Real cutoff: 10680.9588Hz - Error: 0.0041%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7289",
            SPIKES_DIV_OUT  => x"7289",
            SPIKES_DIV_BPF  => x"2025",
Filter_8
        --Ideal cutoff: 9557.6720Hz - Real cutoff: 9557.1043Hz - Error: 0.0059%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7AFB",
            SPIKES_DIV_OUT  => x"7AFB",
            SPIKES_DIV_BPF  => x"2025",
Filter_9
        --Ideal cutoff: 8552.1646Hz - Real cutoff: 8551.7004Hz - Error: 0.0054%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6E0B",
            SPIKES_DIV_OUT  => x"6E0B",
            SPIKES_DIV_BPF  => x"2025",
Filter_10
        --Ideal cutoff: 7652.4407Hz - Real cutoff: 7651.9368Hz - Error: 0.0066%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6277",
            SPIKES_DIV_OUT  => x"6277",
            SPIKES_DIV_BPF  => x"2025",
Filter_11
        --Ideal cutoff: 6847.3716Hz - Real cutoff: 6847.0370Hz - Error: 0.0049%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"757A",
            SPIKES_DIV_OUT  => x"757A",
            SPIKES_DIV_BPF  => x"2025",
Filter_12
        --Ideal cutoff: 6126.9992Hz - Real cutoff: 6126.6797Hz - Error: 0.0052%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"691E",
            SPIKES_DIV_OUT  => x"691E",
            SPIKES_DIV_BPF  => x"2025",
Filter_13
        --Ideal cutoff: 5482.4130Hz - Real cutoff: 5482.1830Hz - Error: 0.0042%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7593",
            SPIKES_DIV_OUT  => x"7593",
            SPIKES_DIV_BPF  => x"2025",
Filter_14
        --Ideal cutoff: 4905.6400Hz - Real cutoff: 4905.4419Hz - Error: 0.0040%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7E3F",
            SPIKES_DIV_OUT  => x"7E3F",
            SPIKES_DIV_BPF  => x"2025",
Filter_15
        --Ideal cutoff: 4389.5460Hz - Real cutoff: 4389.3831Hz - Error: 0.0037%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"70F7",
            SPIKES_DIV_OUT  => x"70F7",
            SPIKES_DIV_BPF  => x"2025",
Filter_16
        --Ideal cutoff: 3927.7472Hz - Real cutoff: 3927.5106Hz - Error: 0.0060%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6514",
            SPIKES_DIV_OUT  => x"6514",
            SPIKES_DIV_BPF  => x"2025",
Filter_17
        --Ideal cutoff: 3514.5316Hz - Real cutoff: 3514.3600Hz - Error: 0.0049%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7898",
            SPIKES_DIV_OUT  => x"7898",
            SPIKES_DIV_BPF  => x"2025",
Filter_18
        --Ideal cutoff: 3144.7880Hz - Real cutoff: 3144.6191Hz - Error: 0.0054%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6BE8",
            SPIKES_DIV_OUT  => x"6BE8",
            SPIKES_DIV_BPF  => x"2025",
Filter_19
        --Ideal cutoff: 2813.9431Hz - Real cutoff: 2813.7647Hz - Error: 0.0063%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"78B1",
            SPIKES_DIV_OUT  => x"78B1",
            SPIKES_DIV_BPF  => x"2025",
Filter_20
        --Ideal cutoff: 2517.9044Hz - Real cutoff: 2517.7899Hz - Error: 0.0045%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"6BFF",
            SPIKES_DIV_OUT  => x"6BFF",
            SPIKES_DIV_BPF  => x"2025",
Filter_21
        --Ideal cutoff: 2253.0102Hz - Real cutoff: 2252.9000Hz - Error: 0.0049%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"73F6",
            SPIKES_DIV_OUT  => x"73F6",
            SPIKES_DIV_BPF  => x"2025",
Filter_22
        --Ideal cutoff: 2015.9840Hz - Real cutoff: 2015.8924Hz - Error: 0.0045%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"67C3",
            SPIKES_DIV_OUT  => x"67C3",
            SPIKES_DIV_BPF  => x"2025",
Filter_23
        --Ideal cutoff: 1803.8940Hz - Real cutoff: 1803.7960Hz - Error: 0.0054%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7BCB",
            SPIKES_DIV_OUT  => x"7BCB",
            SPIKES_DIV_BPF  => x"2025",
Filter_24
        --Ideal cutoff: 1614.1167Hz - Real cutoff: 1614.0306Hz - Error: 0.0053%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6EC5",
            SPIKES_DIV_OUT  => x"6EC5",
            SPIKES_DIV_BPF  => x"2025",
Filter_25
        --Ideal cutoff: 1444.3048Hz - Real cutoff: 1444.2207Hz - Error: 0.0058%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7BE5",
            SPIKES_DIV_OUT  => x"7BE5",
            SPIKES_DIV_BPF  => x"2025",
Filter_26
        --Ideal cutoff: 1292.3578Hz - Real cutoff: 1292.2718Hz - Error: 0.0067%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"6EDC",
            SPIKES_DIV_OUT  => x"6EDC",
            SPIKES_DIV_BPF  => x"2025",
Filter_27
        --Ideal cutoff: 1156.3963Hz - Real cutoff: 1156.3510Hz - Error: 0.0039%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"770A",
            SPIKES_DIV_OUT  => x"770A",
            SPIKES_DIV_BPF  => x"2025",
Filter_28
        --Ideal cutoff: 1034.7386Hz - Real cutoff: 1034.6978Hz - Error: 0.0039%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6A84",
            SPIKES_DIV_OUT  => x"6A84",
            SPIKES_DIV_BPF  => x"2025",
Filter_29
        --Ideal cutoff: 925.8797Hz - Real cutoff: 925.8321Hz - Error: 0.0051%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7F14",
            SPIKES_DIV_OUT  => x"7F14",
            SPIKES_DIV_BPF  => x"2025",
Filter_30
        --Ideal cutoff: 828.4732Hz - Real cutoff: 828.4166Hz - Error: 0.0068%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"71B5",
            SPIKES_DIV_OUT  => x"71B5",
            SPIKES_DIV_BPF  => x"2025",
Filter_31
        --Ideal cutoff: 741.3144Hz - Real cutoff: 741.2804Hz - Error: 0.0046%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7F2F",
            SPIKES_DIV_OUT  => x"7F2F",
            SPIKES_DIV_BPF  => x"2025",
Filter_32
        --Ideal cutoff: 663.3250Hz - Real cutoff: 663.2797Hz - Error: 0.0068%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"71CD",
            SPIKES_DIV_OUT  => x"71CD",
            SPIKES_DIV_BPF  => x"2025",
Filter_33
        --Ideal cutoff: 593.5404Hz - Real cutoff: 593.5055Hz - Error: 0.0059%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7A32",
            SPIKES_DIV_OUT  => x"7A32",
            SPIKES_DIV_BPF  => x"2025",
Filter_34
        --Ideal cutoff: 531.0974Hz - Real cutoff: 531.0662Hz - Error: 0.0059%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6D57",
            SPIKES_DIV_OUT  => x"6D57",
            SPIKES_DIV_BPF  => x"2025",
Filter_35
        --Ideal cutoff: 475.2237Hz - Real cutoff: 475.1914Hz - Error: 0.0068%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"61D6",
            SPIKES_DIV_OUT  => x"61D6",
            SPIKES_DIV_BPF  => x"2025",
Filter_36
        --Ideal cutoff: 425.2282Hz - Real cutoff: 425.2077Hz - Error: 0.0048%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"74BA",
            SPIKES_DIV_OUT  => x"74BA",
            SPIKES_DIV_BPF  => x"2025",
Filter_37
        --Ideal cutoff: 380.4924Hz - Real cutoff: 380.4700Hz - Error: 0.0059%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6872",
            SPIKES_DIV_OUT  => x"6872",
            SPIKES_DIV_BPF  => x"2025",
Filter_38
        --Ideal cutoff: 340.4630Hz - Real cutoff: 340.4508Hz - Error: 0.0036%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"74D3",
            SPIKES_DIV_OUT  => x"74D3",
            SPIKES_DIV_BPF  => x"2025",
Filter_39
        --Ideal cutoff: 304.6448Hz - Real cutoff: 304.6264Hz - Error: 0.0060%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7D70",
            SPIKES_DIV_OUT  => x"7D70",
            SPIKES_DIV_BPF  => x"2025",
Filter_40
        --Ideal cutoff: 272.5949Hz - Real cutoff: 272.5815Hz - Error: 0.0049%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"703E",
            SPIKES_DIV_OUT  => x"703E",
            SPIKES_DIV_BPF  => x"2025",
Filter_41
        --Ideal cutoff: 243.9168Hz - Real cutoff: 243.9042Hz - Error: 0.0052%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"646F",
            SPIKES_DIV_OUT  => x"646F",
            SPIKES_DIV_BPF  => x"2025",
Filter_42
        --Ideal cutoff: 218.2557Hz - Real cutoff: 218.2459Hz - Error: 0.0045%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"77D3",
            SPIKES_DIV_OUT  => x"77D3",
            SPIKES_DIV_BPF  => x"2025",
Filter_43
        --Ideal cutoff: 195.2943Hz - Real cutoff: 195.2865Hz - Error: 0.0040%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6B38",
            SPIKES_DIV_OUT  => x"6B38",
            SPIKES_DIV_BPF  => x"2025",
Filter_44
        --Ideal cutoff: 174.7485Hz - Real cutoff: 174.7390Hz - Error: 0.0054%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"77EC",
            SPIKES_DIV_OUT  => x"77EC",
            SPIKES_DIV_BPF  => x"2025",
Filter_45
        --Ideal cutoff: 156.3642Hz - Real cutoff: 156.3544Hz - Error: 0.0063%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"6B4E",
            SPIKES_DIV_OUT  => x"6B4E",
            SPIKES_DIV_BPF  => x"2025",
Filter_46
        --Ideal cutoff: 139.9140Hz - Real cutoff: 139.9050Hz - Error: 0.0064%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7338",
            SPIKES_DIV_OUT  => x"7338",
            SPIKES_DIV_BPF  => x"2025",
Filter_47
        --Ideal cutoff: 125.1945Hz - Real cutoff: 125.1869Hz - Error: 0.0060%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6719",
            SPIKES_DIV_OUT  => x"6719",
            SPIKES_DIV_BPF  => x"2025",
Filter_48
        --Ideal cutoff: 112.0235Hz - Real cutoff: 112.0187Hz - Error: 0.0043%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7B01",
            SPIKES_DIV_OUT  => x"7B01",
            SPIKES_DIV_BPF  => x"2025",
Filter_49
        --Ideal cutoff: 100.2382Hz - Real cutoff: 100.2330Hz - Error: 0.0051%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"6E10",
            SPIKES_DIV_OUT  => x"6E10",
            SPIKES_DIV_BPF  => x"2025",
Filter_50
        --Ideal cutoff: 89.6927Hz - Real cutoff: 89.6889Hz - Error: 0.0042%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7B1B",
            SPIKES_DIV_OUT  => x"7B1B",
            SPIKES_DIV_BPF  => x"2025",
Filter_51
        --Ideal cutoff: 80.2566Hz - Real cutoff: 80.2519Hz - Error: 0.0059%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"6E27",
            SPIKES_DIV_OUT  => x"6E27",
            SPIKES_DIV_BPF  => x"2025",
Filter_52
        --Ideal cutoff: 71.8133Hz - Real cutoff: 71.8095Hz - Error: 0.0053%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7647",
            SPIKES_DIV_OUT  => x"7647",
            SPIKES_DIV_BPF  => x"2025",
Filter_53
        --Ideal cutoff: 64.2582Hz - Real cutoff: 64.2536Hz - Error: 0.0072%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"69D5",
            SPIKES_DIV_OUT  => x"69D5",
            SPIKES_DIV_BPF  => x"2025",
Filter_54
        --Ideal cutoff: 57.4980Hz - Real cutoff: 57.4945Hz - Error: 0.0060%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"7E44",
            SPIKES_DIV_OUT  => x"7E44",
            SPIKES_DIV_BPF  => x"2025",
Filter_55
        --Ideal cutoff: 51.4490Hz - Real cutoff: 51.4470Hz - Error: 0.0039%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"70FC",
            SPIKES_DIV_OUT  => x"70FC",
            SPIKES_DIV_BPF  => x"2025",
Filter_56
        --Ideal cutoff: 46.0363Hz - Real cutoff: 46.0341Hz - Error: 0.0049%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7E5F",
            SPIKES_DIV_OUT  => x"7E5F",
            SPIKES_DIV_BPF  => x"2025",
Filter_57
        --Ideal cutoff: 41.1931Hz - Real cutoff: 41.1903Hz - Error: 0.0068%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7113",
            SPIKES_DIV_OUT  => x"7113",
            SPIKES_DIV_BPF  => x"2025",
Filter_58
        --Ideal cutoff: 36.8594Hz - Real cutoff: 36.8581Hz - Error: 0.0035%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"796B",
            SPIKES_DIV_OUT  => x"796B",
            SPIKES_DIV_BPF  => x"2025",
Filter_59
        --Ideal cutoff: 32.9816Hz - Real cutoff: 32.9794Hz - Error: 0.0069%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6CA4",
            SPIKES_DIV_OUT  => x"6CA4",
            SPIKES_DIV_BPF  => x"2025",
Filter_60
        --Ideal cutoff: 29.5118Hz - Real cutoff: 29.5097Hz - Error: 0.0071%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"6136",
            SPIKES_DIV_OUT  => x"6136",
            SPIKES_DIV_BPF  => x"2025",
Filter_61
        --Ideal cutoff: 26.4071Hz - Real cutoff: 26.4056Hz - Error: 0.0055%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"73FB",
            SPIKES_DIV_OUT  => x"73FB",
            SPIKES_DIV_BPF  => x"2025",
Filter_62
        --Ideal cutoff: 23.6289Hz - Real cutoff: 23.6273Hz - Error: 0.0069%
            FREQ_DIV        => x"03",
            SPIKES_DIV_FB   => x"67C7",
            SPIKES_DIV_OUT  => x"67C7",
            SPIKES_DIV_BPF  => x"2025",
Filter_63
        --Ideal cutoff: 21.1431Hz - Real cutoff: 21.1423Hz - Error: 0.0037%
            FREQ_DIV        => x"04",
            SPIKES_DIV_FB   => x"7414",
            SPIKES_DIV_OUT  => x"7414",
            SPIKES_DIV_BPF  => x"2025",
Filter_64
        --Ideal cutoff: 18.9187Hz - Real cutoff: 18.9176Hz - Error: 0.0059%
            FREQ_DIV        => x"02",
            SPIKES_DIV_FB   => x"7CA3",
            SPIKES_DIV_OUT  => x"7CA3",
            SPIKES_DIV_BPF  => x"2025",
